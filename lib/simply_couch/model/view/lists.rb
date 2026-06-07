module SimplyCouch
  module Model
    module View
      module Lists
        def self.included(base)
          base.send :extend, ClassMethods
        end

        module ClassMethods
          def list(name, list_function)
            lists[name] = list_function
          end

          def lists(name = nil)
            if name.nil?
              @lists ||= {}
            else
              (@lists && @lists[name]) || (superclass.lists(name) if superclass.respond_to?(:lists))
            end
          end
        end
      end
    end
  end
end
