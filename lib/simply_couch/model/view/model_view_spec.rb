module SimplyCouch
  module Model
    module View
      # A view to return model instances by searching its properties.
      # If you pass reduce => true will count instead
      #
      # example:
      #   view :my_view, :key => :name
      #
      # in addition you can pass in conditions as a javascript string
      #   view :my_view_only_completed, :key => :name, :conditions => 'doc.completed = true'
      # and also a results filter (the results will be run through the given proc):
      #   view :my_view, :key => :name, :results_filter => lambda{|results| results.size}
      class ModelViewSpec < BaseViewSpec
        # The key simply_couch uses for class identification in CouchDB documents
        RUBY_CLASS_KEY = 'ruby_class'

        class JavascriptGenerator
          def initialize(options, klass)
            @options = options
            @klass = klass
          end

          def map_body(&block)
            <<-JS
            function(doc) {
              if(doc.#{RUBY_CLASS_KEY} && doc.#{RUBY_CLASS_KEY} == '#{@klass.name}'#{conditions}) {
                #{yield}
              }
            }
            JS
          end

          def map_function
            map_body do
              "emit(#{formatted_key}, #{emit_value});"
            end
          end

          def formatted_key(_key = nil)
            _key ||= @options[:key]
            if _key.is_a? Array
              '[' + _key.map{|key_part| formatted_key(key_part)}.join(', ') + ']'
            else
              "doc['#{_key}']"
            end
          end

          private

          # Allow custom emit values. Raise when the specified argument is not recognized
          def emit_value
            case @options[:emit_value]
            when Symbol then "doc['#{@options[:emit_value]}']"
            when String then @options[:emit_value]
            when Numeric then @options[:emit_value]
            when NilClass then 1
            else
              raise "The emit value specified is not recognized"
            end
          end

          def conditions
            " && (#{@options[:conditions]})" if @options[:conditions]
          end
        end

        delegate :map_function, :map_body, :formatted_key, :to => :generator

        def view_parameters
          _super = super
          if _super[:reduce]
            _super
          else
            {:include_docs => true, :reduce => false}.merge(_super)
          end
        end

        def reduce_function
          "_sum"
        end

        def process_results(results)
          processed = if count?
                        results['rows'].first.try(:[], 'value') || 0
                      else
                        results['rows'].map {|row|
                          row['doc'] || (row['id'] unless view_parameters[:include_docs])
                        }.compact
                      end
          super processed
        end

        private

        def generator
          @generator ||= JavascriptGenerator.new(@options, @klass)
        end

        def count?
          view_parameters[:reduce]
        end
      end
    end
  end
end
