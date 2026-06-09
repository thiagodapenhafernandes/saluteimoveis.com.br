require "rails_helper"

RSpec.describe Images::WatermarkProcessor do
  it "returns a processed attachable when a watermark is configured" do
    setting = PropertySetting.instance
    setting.update!(watermark_position: "center")
    setting.watermark_image.attach(png_upload("watermark.png", "120x60", "none", "white"))

    upload = png_upload("property.png", "320x220", "#d9e4ec", "#1f2937")

    result = described_class.call(upload, setting: setting)

    expect(result.attachable).to be_a(Hash)
    expect(result.attachable[:filename]).to eq("property.png")
    expect(result.attachable[:content_type]).to eq("image/png")
    expect(result.tempfile).to be_present
    expect(File.size(result.tempfile.path)).to be_positive
  ensure
    result&.tempfile&.close!
  end

  it "keeps the original upload when there is no watermark image" do
    setting = PropertySetting.instance
    upload = png_upload("property.png", "320x220", "#d9e4ec", "#1f2937")

    result = described_class.call(upload, setting: setting)

    expect(result.attachable).to eq(upload)
    expect(result.tempfile).to be_nil
  end

  def png_upload(filename, size, background, fill)
    file = Tempfile.new([File.basename(filename, ".png"), ".png"])
    file.close
    system("magick", "-size", size, "xc:#{background}", "-fill", fill, "-draw", "rectangle 10,10 90,40", file.path, exception: true)
    Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: filename)
  end
end
