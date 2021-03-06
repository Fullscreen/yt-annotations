require 'yt/annotations/branding'
require 'yt/annotations/card'
require 'yt/annotations/end_screen'
require 'yt/annotations/label'
require 'yt/annotations/note'
require 'yt/annotations/speech'
require 'yt/annotations/spotlight'
require 'yt/annotations/title'
require 'yt/annotations/pause'
require 'yt/annotations/promotion'

# An object-oriented Ruby client for YouTube.
# @see http://www.rubydoc.info/gems/yt/
module Yt
  module Annotations
    # Provides a method to fetch annotations and cards for a YouTube video.
    module For
      # @param [String] video_id the unique ID of a YouTube video.
      # @return [Array<Yt::Annotation>] the annotations/end cards of the video.
      def for(video_id)
        (annotations(video_id) + end_screens(video_id)).sort_by(&:starts_at)
      end

    private

      def annotations(video_id)
        data = fetch "/annotations_invideo?video_id=#{video_id}"
        xml_to_annotations(Hash.from_xml data)
      end

      def end_screens(video_id)
        data = fetch "/get_endscreen?v=#{video_id}"
        data = data.partition("\n").last
        data.present? ? json_to_annotations(JSON data) : []
      end

      def fetch(path)
        request = Net::HTTP::Get.new path
        options = ['www.youtube.com', 443, {use_ssl: true}]
        response = Net::HTTP.start(*options) {|http| http.request request}
        response.body
      end

      def xml_to_annotations(xml)
        annotations = xml['document']['annotations']
        annotations = Array.wrap (annotations || {})['annotation']
        annotations = merge_highlights annotations
        annotations = exclude_drawers annotations
        annotations.map{|data| annotation_class(data).new data}
      end

      def json_to_annotations(json)
        annotations = json['elements']
        annotations.map{|data| Annotations::EndScreen.new data['endscreenElementRenderer']}
      end

      def annotation_class(data)
        case data['style']
          when 'anchored', 'speech' then Annotations::Speech
          when 'branding' then Annotations::Branding
          when 'highlightText' then Annotations::Spotlight
          when 'label' then Annotations::Label
          when 'popup' then Annotations::Note
          when 'title' then Annotations::Title
          else case data['type']
            when 'card' then Annotations::Card
            when 'pause' then Annotations::Pause
            when 'promotion' then Annotations::Promotion
          end
        end
      end

      def exclude_drawers(annotations)
        annotations.reject{|a| a['type'] == 'drawer'}
      end

      def merge_highlights(annotations)
        highlights, others = annotations.partition{|a| a['type'] == 'highlight'}
        highlights.each do |highlight|
          match = others.find do |a|
            (a['segment'] || {})['spaceRelative'] == highlight['id']
          end
          match.merge! highlight if match
        end
        others
      end
    end
  end
end
