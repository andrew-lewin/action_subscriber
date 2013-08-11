module ActionSubscriber
  module Router
    def self.included(klass)
      klass.class_eval do
        extend ::ActionSubscriber::Router::ClassMethods
        include ::ActionSubscriber::Router::InstanceMethods
      end
    end

    module ClassMethods
      def generate_queue_name(method_name)
        [ 
          local_application_name,
          remote_application_name,
          resource_name,
          method_name
        ].compact.join('.')
      end

      def generate_routing_key_name(method_name)
        [ 
          remote_application_name,
          resource_name,
          method_name
        ].compact.join('.')
      end

      def local_application_name(reload = false)
        if reload || @_local_application_name.nil?
          @_local_application_name = case
                                when ENV['APP_NAME'] then
                                  ENV['APP_NAME'].to_s.dup
                                when defined?(::Rails) then
                                  ::Rails.application.class.parent_name.dup
                                else
                                  raise "Define an application name (ENV['APP_NAME'])"
                                end

          @_local_application_name.downcase!
        end
        @_local_application_name
      end

      def print_routes
        exchange_names.each do |exchange_name|
          puts "-- Exchange : #{exchange_name}"
          subscribable_methods.each do |method|
            puts "  -- :#{method}"
            puts "    -- queue :       #{queue_names[method]}"
            puts "    -- routing_key : #{routing_key_names[method]}"
          end
        end
      end

      # Build the `queue` for a given method.
      #
      # If the queue name is not set, the queue name is
      #   "local.remote.resoure.action"
      #
      # Example
      #   "newman.amigo.user.created"
      #
      def queue_name_for_method(method_name)
        return queue_names[method_name] if queue_names[method_name]

        queue_name = generate_queue_name(method_name)
        queue_for(method_name, queue_name)
        return queue_name
      end

      # The name of the resource respresented by this subscriber.
      # If the class name were `UserSubscriber` the resource_name would be `user`.
      #
      def resource_name
        @_resource_name ||= self.name.underscore.gsub(/_subscriber/, '').to_s
      end

      # Build the `routing_key` for a given method.
      #
      # If the routing_key name is not set, the routing_key name is
      #   "remote.resoure.action"
      #
      # Example
      #   "amigo.user.created"
      #
      def routing_key_name_for_method(method_name)
        return routing_key_names[method_name] if routing_key_names[method_name]

        routing_key_name = generate_routing_key_name(method_name)
        routing_key_for(method_name, routing_key_name)
        return routing_key_name
      end

      def subscribable_methods
        @_subscribable_methods ||= instance_methods.sort - ::Object.instance_methods - unwanted_methods
      end

      def unwanted_methods
        [:consume_event, :payload]
      end
    end

    module InstanceMethods

      def consume_event
        self.__send__(resource_action, payload)
      rescue => e
        # TODO: error handling interface
        raise
      end

      private

      # Return the last element of the routing key to indicate which action
      # has occurred on the resource.
      #
      def resource_action
        routing_key.split('.').last.to_s
      end

      def routing_key
        header.method.routing_key
      end
    end
  end
end