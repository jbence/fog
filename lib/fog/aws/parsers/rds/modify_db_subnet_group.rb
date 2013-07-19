module Fog
  module Parsers
    module AWS
      module RDS

        require 'fog/aws/parsers/rds/subnet_group_parser'

        class ModifyDBSubnetGroup < Fog::Parsers::AWS::RDS::SubnetGroupParser
          def reset
            @response = { 'ModifyDBSubnetGroupResult' => {}, 'ResponseMetadata' => {} }
            super
          end
        end

      end
    end
  end
end

