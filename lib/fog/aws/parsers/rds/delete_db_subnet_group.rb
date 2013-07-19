module Fog
  module Parsers
    module AWS
      module RDS

        require 'fog/aws/parsers/rds/subnet_group_parser'

        class DeleteDBSubnetGroup < Fog::Parsers::AWS::RDS::SubnetGroupParser
          def reset
            @response = {'DeleteDBSubnetGroupResult' => {}, 'ResponseMetadata' => {}}
            super
          end
        end

      end
    end
  end
end

