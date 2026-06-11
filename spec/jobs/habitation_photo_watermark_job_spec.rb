require "rails_helper"

RSpec.describe HabitationPhotoWatermarkJob, type: :job do
  it "applies watermark to the attachment blob without changing the attachment id" do
    setting = PropertySetting.instance
    setting.watermark_image.attach(io: StringIO.new("watermark"), filename: "watermark.png", content_type: "image/png")

    habitation = create(:habitation, codigo: "JOB-WATERMARK-#{SecureRandom.hex(6)}")
    habitation.photos.attach(io: StringIO.new("original photo"), filename: "original.jpg", content_type: "image/jpeg")

    attachment = habitation.photos.attachments.first
    original_blob = attachment.blob
    output = Tempfile.new(["watermarked", ".jpg"])
    output.write("watermarked photo")
    output.rewind

    result = Images::WatermarkProcessor::Result.new(
      attachable: { io: output, filename: "original.jpg", content_type: "image/jpeg" },
      tempfile: output
    )
    allow(Images::WatermarkProcessor).to receive(:call).and_return(result)

    described_class.perform_now(habitation.id, [attachment.id], setting.id)

    attachment.reload
    expect(attachment.id).to eq(habitation.photos.attachments.first.id)
    expect(attachment.blob_id).not_to eq(original_blob.id)
    expect(attachment.blob.metadata).to include(
      "salute_watermarked" => true,
      "salute_original_blob_id" => original_blob.id
    )
  ensure
    output&.close!
  end
end
