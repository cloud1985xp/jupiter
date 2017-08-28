module Jupyter
  class Error < StandardError
  end

  class LogParseError < Error
  end

  class ConfigurationNotFoundError < Error
  end
end