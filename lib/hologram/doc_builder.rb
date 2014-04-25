module Hologram
  class DocBuilder
    attr_accessor :source, :destination, :documentation_assets, :dependencies, :index, :base_path, :renderer, :doc_blocks, :pages
    attr_reader :errors
    attr :doc_assets_dir, :output_dir, :input_dir, :header_erb, :footer_erb

    def self.from_yaml(yaml_file)
      config = YAML::load_file(yaml_file)
      raise SyntaxError if !config.is_a? Hash

      new(config.merge(
        'base_path' => Pathname.new(yaml_file).dirname,
        'renderer' => Utils.get_markdown_renderer(config['custom_markdown'])
      ))

    rescue SyntaxError, ArgumentError, Psych::SyntaxError
      raise SyntaxError, "Could not load config file, check the syntax or try 'hologram init' to get started"
    end

    def initialize(options)
      @pages = {}
      @errors = []
      @dependencies = options.fetch('dependencies', [])
      @index = options['index']
      @base_path = options.fetch('base_path', Dir.pwd)
      @renderer = options.fetch('renderer', MarkdownRenderer)
      @source = options['source']
      @destination = options['destination']
      @documentation_assets = options['documentation_assets']
    end

    def build
      set_dirs
      return false if !is_valid?

      set_header_footer
      current_path = Dir.pwd
      Dir.chdir(base_path)
      # Create the output directory if it doesn't exist
      FileUtils.mkdir_p(destination) if !output_dir
      # the real work happens here.
      build_docs
      Dir.chdir(current_path)
      DisplayMessage.success("Build completed. (-: ")
      true
    end

    def is_valid?
      errors.clear
      set_dirs
      errors << "No source directory specified in the config file" if !source
      errors << "No destination directory specified in the config" if !destination
      errors << "No documentation assets directory specified" if !documentation_assets
      errors << "Can not read source directory (#{source}), does it exist?" if source && !input_dir
      errors.empty?
    end

    private

    def set_dirs
      @output_dir = real_dir_path(destination)
      @doc_assets_dir = real_dir_path(documentation_assets)
      @input_dir = real_dir_path(source)
    end

    def real_dir_path(dir)
      return if !File.directory?(String(dir))
      Pathname.new(dir).realpath
    end

    def real_file_path(filepath)
      return if !File.exists?(filepath)
      Pathname.new(filepath).realpath
    end

    def build_docs
      doc_parser = DocParser.new(input_dir, index)
      @pages, @categories = doc_parser.parse

      if index && !@pages.has_key?(index + '.html')
        DisplayMessage.warning("Could not generate index.html, there was no content generated for the category #{config['index']}.")
      end

      warn_missing_doc_assets
      write_docs
      copy_dependencies
      copy_assets
    end

    def copy_assets
      return unless doc_assets_dir
      Dir.foreach(doc_assets_dir) do |item|
        # ignore . and .. directories and files that start with
        # underscore
        next if item == '.' or item == '..' or item.start_with?('_')
        `rm -rf #{output_dir}/#{item}`
        `cp -R #{doc_assets_dir}/#{item} #{output_dir}/#{item}`
      end
    end

    def copy_dependencies
      dependencies.each do |dir|
        begin
          dirpath  = Pathname.new(dir).realpath
          if File.directory?("#{dir}")
            `rm -rf #{output_dir}/#{dirpath.basename}`
            `cp -R #{dirpath} #{output_dir}/#{dirpath.basename}`
          end
        rescue
          DisplayMessage.warning("Could not copy dependency: #{dir}")
        end
      end
    end

    def write_docs
      markdown = Redcarpet::Markdown.new(renderer, { :fenced_code_blocks => true, :tables => true })
      tpl_vars = TemplateVariables.new({:categories => @categories})
      #generate html from markdown
      @pages.each do |file_name, page|
        title = page[:blocks].empty? ? "" : page[:blocks][0][:category]
        tpl_vars.set_args({:title => title, :file_name => file_name, :blocks => page[:blocks]})
        write_page(file_name, markdown.render(page[:md]), tpl_vars.get_binding)
      end
    end

    def write_page(file_name, body, binding)
      fh = get_fh(output_dir, file_name)
      fh.write(header_erb.result(binding)) if header_erb
      fh.write(body)
      fh.write(footer_erb.result(binding)) if footer_erb
    ensure
      fh.close
    end

    def set_header_footer
      ['header', 'footer'].each do |section|
        deprecated_name = "#{doc_assets_dir}/#{section}.html"
        filename = "#{doc_assets_dir}/_#{section}.html"
        erb_file = real_file_path(filename) || real_file_path(deprecated_name)

        erb = ERB.new(File.read(erb_file)) if erb_file
        instance_variable_set("@#{section}_erb", erb)

        next if erb_file
        DisplayMessage.warning("No _#{section}.html found in documentation assets. Without this your css/header will not be included on the generated pages.")
      end
    end

    def get_file_name(str)
      str.gsub(' ', '_').downcase + '.html'
    end

    def get_fh(output_dir, output_file)
      File.open("#{output_dir}/#{output_file}", 'w')
    end

    def warn_missing_doc_assets
      return if doc_assets_dir
      DisplayMessage.warning("Could not find documentation assets at #{documentation_assets}")
    end
  end
end
