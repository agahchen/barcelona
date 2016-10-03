class ContainerInstance
  attr_accessor :district

  def initialize(district)
    @district = district
  end

  def user_data
    user_data = InstanceUserData.new
    user_data.packages += ["aws-cli", "jq", "aws-cfn-bootstrap"]
    user_data.run_commands += [
      "set -e",
      "MEMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`",
      "if [ $MEMSIZE -lt 2097152 ]; then",
      "  SIZE=$((MEMSIZE * 2))k",
      "elif [ $MEMSIZE -lt 8388608 ]; then",
      "  SIZE=${MEMSIZE}k",
      "else",
      "  SIZE=8388608k",
      "fi",
      "fallocate -l $SIZE /swap.img && mkswap /swap.img && chmod 600 /swap.img && swapon /swap.img",
      "AWS_REGION=#{district.region}",
      "aws configure set s3.signature_version s3v4",
      "aws s3 cp s3://#{district.s3_bucket_name}/#{district.name}/ecs.config /etc/ecs/ecs.config",
      "chmod 600 /etc/ecs/ecs.config",
      "sed -i 's/^#\\s%wheel\\s*ALL=(ALL)\\s*NOPASSWD:\\sALL$/%wheel\\tALL=(ALL)\\tNOPASSWD:\\tALL/g' /etc/sudoers",
      "chkconfig --add barcelona",
      "chkconfig barcelona on",
      "service barcelona start"
    ]

    user_data.add_file("/etc/init.d/barcelona", "root:root", "755", <<EOS)
#!/bin/bash
# chkconfig: 2345 96 04
# description: Barcelona

set -e

stop() {
  AWS_REGION=#{district.region}
  ecs_cluster=`curl http://localhost:51678/v1/metadata | jq -r .Cluster`
  container_instance_arn=`curl http://localhost:51678/v1/metadata | jq -r .ContainerInstanceArn | cut -d / -f2`

  aws ecs deregister-container-instance --region $AWS_REGION --cluster $ecs_cluster --container-instance $container_instance_arn --force
  sleep 60

  docker stop -t 90 $(docker ps -q)
}

case "$1" in
  start)
    touch /var/lock/subsys/barcelona
    ;;
  stop)
    stop
    rm /var/lock/subsys/barcelona
    ;;
  *) exit 2;;
esac
EOS

    district.users.each do |user|
      user_data.add_user(user.name, authorized_keys: [user.public_key], groups: user.instance_groups)
      if district.dockercfg.present?
        name = user.name
        dockercfg = {"auths" => district.dockercfg}.to_json
        dockercfg_path = "/home/#{name}/.docker"
        user_data.run_commands += [
          "mkdir #{dockercfg_path}",
          "echo '#{dockercfg}' > #{dockercfg_path}/config.json",
          "chmod 600 #{dockercfg_path}/config.json",
          "chown #{name}:#{name} #{dockercfg_path}/config.json"
        ]
      end
    end

    user_data = district.hook_plugins(:container_instance_user_data, self, user_data)
  end
end
