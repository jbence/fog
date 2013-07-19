module Fog
  module AWS
    class RDS
      class Real

        require 'fog/aws/parsers/rds/modify_db_subnet_group'

        # Modifies an existing DB subnet group. DB subnet groups must contain at least one subnet in each AZ in the region.
        # http://docs.amazonwebservices.com/AmazonRDS/2012-01-15/APIReference/API_ModifyDBSubnetGroup.html
        # ==== Parameters
        # * DBSubnetGroupName <~String> - The name for the DB Subnet Group. This value is stored as a lowercase string.
        #   Must contain no more than 255 alphanumeric characters or hyphens. Must not be "Default". Required.
        # * SubnetIds <~Array> - The EC2 Subnet IDs for the DB Subnet Group. Required.
        # * DBSubnetGroupDescription <~String> - The description for the DB Subnet Group. Optional.
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        def modify_db_subnet_group(name, subnet_ids, description = name)
          params = { 'Action' => 'ModifyDBSubnetGroup',
                     'DBSubnetGroupName' => name,
                     'DBSubnetGroupDescription' => description,
                     :parser   => Fog::Parsers::AWS::RDS::DeleteDBSubnetGroup.new }
          params.merge!(Fog::AWS.indexed_param('SubnetIds.member', Array(subnet_ids)))
          request(params)
        end

      end

      class Mock

        def modify_db_subnet_group(name, subnet_ids, description = name)
          response = Excon::Response.new
          unless self.data[:subnet_groups] && self.data[:subnet_groups][name]
            raise Fog::AWS::RDS::NotFound.new("The subnet group '#{name}' does not exist")
          end

          subnets = subnet_ids.map { |snid| Fog::Compute[:aws].subnets.get(snid) }
          vpc_id = subnets.first.vpc_id

          data = {
              'DBSubnetGroupName' => name,
              'DBSubnetGroupDescription' => description,
              'SubnetGroupStatus' => 'Complete',
              'Subnets' => subnet_ids,
              'VpcId' => vpc_id
          }
          self.data[:subnet_groups][name] = data
          response.body = {
              'ResponseMetadata' => { 'RequestId' => Fog::AWS::Mock.request_id },
              'ModifyDBSubnetGroupResult' => { 'DBSubnetGroup' => data }
          }
          response

        end

      end
    end
  end
end
