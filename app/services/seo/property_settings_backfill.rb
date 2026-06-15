module Seo
  class PropertySettingsBackfill
    Result = Struct.new(:scanned, :updated, :skipped_manual, :missing_habitation, keyword_init: true)

    def initialize(scope: SeoSetting.where("canonical_key LIKE ?", "property:%"), dry_run: false)
      @scope = scope
      @dry_run = dry_run
      @result = Result.new(scanned: 0, updated: 0, skipped_manual: 0, missing_habitation: 0)
    end

    def call
      @scope.find_each do |seo|
        @result.scanned += 1

        if seo.manual_mode?
          @result.skipped_manual += 1
          next
        end

        habitation = habitation_for(seo)
        unless habitation
          @result.missing_habitation += 1
          next
        end

        attributes = PropertyMetadataBuilder.new(habitation).attributes.merge(
          controller_name: "habitations",
          action_name: "show",
          normalized_params: {},
          robots_index: true,
          robots_follow: true,
          active: true,
          apply_to_public: true,
          auto_discovered: true
        )

        changes = attributes.any? do |attribute, value|
          seo.public_send(attribute) != value
        end
        next unless changes

        @result.updated += 1
        seo.update!(attributes) unless @dry_run
      end

      @result
    end

    private

    def habitation_for(seo)
      identifier = seo.canonical_key.to_s[/\Aproperty:(.+)\z/, 1]
      return if identifier.blank?

      Habitation.find_by(codigo: identifier) || Habitation.find_by(id: identifier)
    end
  end
end
