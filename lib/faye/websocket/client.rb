module Faye
  class WebSocket

    class Client
      include API

      def initialize(url, protocols = nil)
        @url = url
        @uri = URI.parse(url)

        @parser = ::WebSocket::Protocol.client(self, :protocols => protocols)
        @parser.onopen    { open }
        @parser.onmessage { |message| receive_message(message) }
        @parser.onclose   { |reason, code| finalize(reason, code) }

        @ready_state = CONNECTING
        @buffered_amount = 0

        port = @uri.port || (@uri.scheme == 'wss' ? 443 : 80)

        EventMachine.connect(@uri.host, port, Connection) do |conn|
          @stream = conn
          conn.parent = self
        end
      end

      def write(data)
        @stream.write(data)
      end

    private

      def on_connect
        @stream.start_tls if @uri.scheme == 'wss'
        @parser.start
      end

      def parse(data)
        @parser.parse(data)
      end

      module Connection
        attr_accessor :parent

        def connection_completed
          parent.__send__(:on_connect)
        end

        def receive_data(data)
          parent.__send__(:parse, data)
        end

        def unbind
          parent.__send__(:finalize, '', 1006)
        end

        def write(data)
          send_data(data) rescue nil
        end
      end
    end

  end
end
