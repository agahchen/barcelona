class DeployRunnerJob < ActiveJob::Base
  queue_as :default

  def perform(heritage, without_before_deploy:)
    heritage.events.create(level: :good, message: "Deploying #{heritage.name}(#{heritage.image_path}) to #{heritage.district.name} district...")
    before_deploy = heritage.before_deploy
    if before_deploy.present? && !without_before_deploy
      oneoff = heritage.oneoffs.create!(command: before_deploy)
      oneoff.run!(sync: true)
      if oneoff.exit_code != 0
        heritage.events.create(level: :error, message: "The command `#{before_deploy}` failed. Stopped deploying.")
        return
      else
        heritage.events.create(level: :good, message:  "before_deploy script `#{before_deploy}` successfully finished")
      end
    end

    heritage.services.each do |service|
      Rails.logger.info "Updating service #{service.service_name} ..."
      begin
        service.apply
      rescue => e
        Rails.logger.error "#{e.class}: #{e.message}"
        Rails.logger.error caller.join("\n")
        heritage.events.create(
          level: :error,
          message: "Deploy failed: Something went wrong with deploying #{service.service_name}"
        )
      end
    end

    heritage.services.each do |service|
      MonitorDeploymentJob.perform_later(service)
    end
  end
end
