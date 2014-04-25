module Hologram
  class CLI
    attr_reader :args

    def initialize(args)
      @args = args
    end

    def run
      return setup if args[0] == 'init'
      args.empty? ? build : build(args[0])
    end

    private

    def build(config = 'hologram_config.yml')
      builder = DocBuilder.from_yaml(config)
      DisplayMessage.error(builder.errors.first) if !builder.is_valid?
      builder.build
    rescue Errno::ENOENT
      DisplayMessage.error("Could not load config file, try 'hologram init' to get started")
    rescue => e
      DisplayMessage.error(e.message)
    end

    def setup
      Hologram::Utils.setup_dir
    rescue => e
      DisplayMessage.error("#{e}")
    end
  end
end
