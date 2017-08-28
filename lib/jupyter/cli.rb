require 'optparse'

module Jupyter
  class CLI
    include Singleton

    attr_reader :options, :plan_name

    def initialize(args = ARGV)
      @args = args
      @options = {}
      @remote_server_list = []
      Time.zone = "Etc/UTC"
      parse!

      str = options.fetch(:file, 'default')
      @plan_name = if str[-3..-1] == '.rb'
        str[0..-4]
      else
        str
      end
    end

    def run
      @starts_at = Time.zone.now
      @timestamp = @starts_at.to_i

      prepare!

      log("Running with threads: #{Jupyter.settings.threads}, loop_controller: #{Jupyter.settings.loop_controller}")
      execute!

      @ends_at = Time.zone.now

      generate_report!
    rescue => e
      puts e.message
      puts e.backtrace
    end

    private

    def generate_report!
      # TODO: Wrap with Object
      report = {
        'plan': ruby_filename,
        'starts_at': @starts_at,
        'ends_at': @ends_at,
        'settings': {
          'threads': Jupyter.settings.threads,
          'loop_controller': Jupyter.settings.loop_controller
        }
      }

      # JMeter Summary
      unless debug?
        logs = `tail -n 10 #{log_file}`.split("\n")
        log = logs.reverse.detect { |str| str["summary ="] }
        stats = log.scan(/(Avg|Min|Max): +(\d)/).each { |k,v| report[k.downcase] =  v.to_f }
        summary = log.match(/summary = +(\d+) in +([\d\.]+)s = +([\d\.]+)\/s/)
        error = log.match(/(Err): +(\d+) \(([\d\.]+)%\)/)

        report['summary'] = summary[1].to_f
        report['seconds'] = summary[2].to_f
        report['rate'] = summary[3].to_f
        report['error_count'] = error[2].to_f
        report['error_rate'] = error[3].to_f
      end

      # CloudWatch
      report['cloudwatch'] = fetch_cloudwatch_statistics! if enabled_cloudwatch?

      # TODO: NewRelic RPM

      case output_destination
      when /.csv$/
        write_to_csv(report)
      when "sqs", "SQS"
        send_to_sqs(report)
      when 'table'
        print_table(report)
      else
        require 'pp'
        PP.pp(report)
      end
    end

    def print_table(report)
      require 'text-table'

      table = Text::Table.new
      head = []
      row = []

      dumper = ->(k, v, prefix = '') {
        if v.is_a?(Hash)
          v.each { |x, y| dumper.call(x, y, "#{k}-") }
        else
          head << "#{prefix}#{k}"
          row << v
        end
      }

      report.each(&dumper)

      table.head = head
      table.rows = [row]

      puts table.to_s
    end

    # TODO!
    def write_to_csv(_report)
      raise NotImplementedError
    end

    def send_to_sqs(report)
      raise Jupyter::ConfigurationNotFoundError, :sqs unless config.aws.enabled_sqs?

      sqs = ::Aws::SQS::Client.new(config.aws.credential)
      sqs_config = config.aws.sqs
      queue_url = sqs.get_queue_url(queue_name: sqs_config['queue_name']).queue_url

      send_message_result = sqs.send_message({
        queue_url: queue_url,
        message_body: report.to_json
      })
    end

    def parse!
      stage = @args.shift if @args[0].in? config.available_stages
      stage ||= 'development'
      @options[:stage] = stage

      @action = 'run'

      parser = OptionParser.new do |opts|
        opts.banner = "jupyter [action] [options]"
        opts.on('-f name', '--file name', 'the plan name of your ruby file (default.rb)') do |arg|
          options[:file] = arg
        end

        opts.on('-r', '--remote', 'execute on remote servers with given IP list') do |arg|
          options[:remote] = true
        end

        opts.on('--rampup value', 'specify rampup value') do |arg|
          options[:rampup] = arg.to_i
        end

        opts.on('--threads value', 'specify threads count') do |arg|
          options[:threads] = arg.to_i
        end

        opts.on('--cloudwatch-delay', 'delayed seconds before query cloudwatch') do |arg|
          options[:cloudwatch_delay] = arg.to_i
        end

        opts.on('--loop value', 'specify loop controller') do |arg|
          options[:loop] = arg.to_i
        end

        opts.on('--output dest', 'specify output destination') do |arg|
          options[:output] = arg
        end

        opts.on('-l file', '--log file', 'specify log file') do |arg|
          options[:log_file] = arg
        end

        opts.on('--debug', 'debug mode') do |arg|
          options[:debug] = true
        end
      end

      parser.parse!

      Jupyter.env = stage
      Jupyter.options = options
    end

    def prepare!
      fetch_remote_server_list! if @options[:remote]
      generate_jmx_file
    end

    def debug?
      @options[:debug] || ENV['DEBUG'].present?
    end

    def execute!
      slave_list = nil
      remote = @remote_server_list.any? ? " -R #{@remote_server_list.join(',')}" : ""

      command = "jmeter -n -t #{jmx_file} -j #{log_file}#{remote}"

      if debug?
        puts "[DEBUG] #{command}"
      else
        puts command
        `#{command}`
      end
    end

    def generate_jmx_file
      proc = Proc.new {}
      plan_file = "#{plan_directory}#{ruby_filename}"
      x = eval(File.open(plan_file).read, proc.binding, ruby_filename)
      x.jmx(file: jmx_file)
    end

    # TODO: configurable
    def plan_directory
      "plans/"
    end

    def ruby_filename
      @ruby_filename ||= "#{plan_name}.rb"
    end

    def jmx_file
      @jmx_filename ||= "tmp/#{plan_name}-#{@timestamp}.jmx"
    end

    def log_file
      @log_file ||= begin
        file = options.fetch(:log_file, "jupyter.log")
        "log/#{file}"
      end
    end

    def output_destination
      @output_destination ||= options.fetch(:output, :stdout)
    end

    def fetch_remote_server_list!
      client = ::Aws::EC2::Client.new(config.aws.credential)

      reservations = client.describe_instances(filters: config.aws.slave_filters).reservations
      instances = reservations.map(&:instances).flatten
      @remote_server_list = instances.map(&:private_ip_address)

      fail 'RemoteServerNotFound' if @remote_server_list.empty?
    end

    def fetch_cloudwatch_statistics!
      cloudwatch = {}
      st = @starts_at.iso8601
      et = @ends_at.iso8601

      cloudwatch_wait_seconds = options.fetch(:cloudwatch_delay, 0)
      if cloudwatch_wait_seconds > 0
        puts "Wait #{cloudwatch_wait_seconds} seconds to collect data from cloudwatch"
        sleep(cloudwatch_wait_seconds)
      end

      cloudwatch_statistics_mapping = {
        'RequestCount' => { statistics: ["Sum"], calculations: { rpm: :sum } } ,
        'CPUUtilization' => { statistics: ["Maximum", "Average"], calculations: { cpu_max: :maximum, cpu_avg: :average } },
        'HealthyHostCount' => { statistics: ["Maximum"], calculations: { count: :maximum } }
      }

      client = Aws::CloudWatch::Client.new(config.aws.credential)

      config.aws.cloudwatch.each do |metric_name, namespaces|
        namespaces.each do |namespace, subjects|
          metric = Aws::CloudWatch::Metric.new("AWS/#{namespace.upcase}", metric_name, client: client)
          subjects.each do |subject_name, dimensions|
            statistics = cloudwatch_statistics_mapping[metric_name][:statistics]
            calculations = cloudwatch_statistics_mapping[metric_name][:calculations]

            d = dimensions.map { |k,v| { name: k, value: v } }
            resp = metric.get_statistics({
              dimensions: d,
              start_time: st, end_time: et,
              period: 60,
              statistics: statistics
            })

            datapoints = resp.datapoints

            cloudwatch[subject_name] ||= {}

            h = calculations.each_with_object({}) do |(name, method), h|
              h[name] = datapoints.map(&method).max.to_f
            end

            cloudwatch[subject_name].merge!(h)
          end
        end
      end

      cloudwatch
    end

    def enabled_cloudwatch?
      @options[:remote] && config.aws.enabled_cloudwatch?
    end

    def config
      Jupyter.config
    end

    def log(text)
      print (debug? ? '[DEBUG] ' : '')
      puts text
    end
  end
end
