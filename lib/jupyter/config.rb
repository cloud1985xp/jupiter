module Jupyter
  class Config
    attr_reader :aws, :available_stages

    def initialize(env = 'development')
      data = YAML.load(ERB.new(File.read("./config/jupyter.yml")).result)
      @available_stages = Array(data.keys)
      @config = data[env]
      @aws = AWS.new(@config['aws'])
    end
  end

  class AWS
    def initialize(config)
      @config = config
    end

    def [](key)
      @config[key.to_s]
    end

    def load_balancer_name
      @config["load_balancer_name"]
    end

    def cloudwatch
      @config["cloudwatch"]
    end

    def sqs
      @config['sqs']
    end

    def enabled_cloudwatch?
      cloudwatch.present?
    end

    def enabled_sqs?
      sqs.present?
    end

    def slave_filters
      state_filter = [{ name: 'instance-state-name', values: ['running'] }]

      tags = @config['slave_filters']["tags"].map do |tag_name, value|
        { name: "tag:Name", values: value.split(',') }
      end

      attrs = @config['slave_filters']['attrs']

      state_filter + tags + Array(attrs)
    end

    def credential
      {
        access_key_id: @config['access_key_id'],
        secret_access_key: @config['secret_access_key'],
        region: @config['region']
      }
    end
  end
end
