module Hologram
  module Utils
    def self.get_markdown_renderer(custom_markdown = nil)
      return MarkdownRenderer if custom_markdown.nil?

      load custom_markdown
      renderer_class = File.basename(custom_markdown, '.rb').split(/_/).map(&:capitalize).join
      DisplayMessage.info("Custom markdown renderer #{renderer_class} loaded.")
      Module.const_get(renderer_class)
    rescue LoadError => e
      DisplayMessage.error("Could not load #{custom_markdown}.")
    rescue NameError => e
      DisplayMessage.error("Class #{renderer_class} not found in #{custom_markdown}.")
    end

    def self.setup_dir
      if File.exists?("hologram_config.yml")
        DisplayMessage.warning("Cowardly refusing to overwrite existing hologram_config.yml")
        return
      end

      FileUtils.cp_r INIT_TEMPLATE_FILES, Dir.pwd
      new_files = ["hologram_config.yml", "doc_assets/", "doc_assets/_header.html", "doc_assets/_footer.html"]
      DisplayMessage.created(new_files)
    end
  end
end
