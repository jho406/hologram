require 'spec_helper'

describe Hologram::Utils do
  subject(:utils) { Hologram::Utils }

  context '.get_markdown_renderer' do

    around do |example|
      Hologram::DisplayMessage.quiet!
      current_dir = Dir.pwd
      Dir.chdir('spec/fixtures/renderer')

      example.run

      Dir.chdir(current_dir)
      Hologram::DisplayMessage.show!
    end

    context 'by default' do
      let(:renderer) { utils.get_markdown_renderer }

      it 'returns the standard hologram markdown renderer' do
        expect(renderer).to eql Hologram::MarkdownRenderer
      end
    end

    context 'when passed a valid custom renderer' do
      let(:renderer) { utils.get_markdown_renderer('valid_renderer.rb') }

      it 'returns the custom renderer' do
        expect(renderer).to eql ValidRenderer
      end
    end

    context 'when passed an invalid custom renderer' do
      context 'expecting a class named as the upper camel cased version of the file name' do
        it 'exits' do
          expect {
            utils.get_markdown_renderer('invalid_renderer.rb')
          }.to raise_error SystemExit
        end
      end

      context 'expecting a filename.rb' do
        it 'exits' do
          expect {
            utils.get_markdown_renderer('foo')
          }.to raise_error SystemExit
        end
      end
    end
  end

  context '.setup_dir' do
    around do |example|
      capture(:stdout) do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            example.run
          end
        end
      end
    end

    before do
      utils.setup_dir
    end

    it 'creates a config file' do
      expect(File.exists?('hologram_config.yml')).to be_true
    end

    it 'creates default assets' do
      Dir.chdir('doc_assets') do
        ['_header.html', '_footer.html'].each do |asset|
          expect(File.exists?(asset)).to be_true
        end
      end
    end

    context 'when a hologram_config.yml already exists' do
      it 'does nothing' do
        open('hologram_config.yml', 'w') {|io|io << 'foo'}
        utils.setup_dir
        expect(IO.read('hologram_config.yml')).to eql('foo')
      end
    end
  end
end
