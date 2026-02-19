module Leads
  class PocketExpirationJob < ApplicationJob
    queue_as :default

    def perform(lead_id)
      lead = Lead.find_by(id: lead_id)
      return unless lead && lead.status == "waiting_acceptance"

      # Se o lead ainda está aguardando aceite após o tempo de pocket
      # Vamos redistribuí-lo (marcar como recebido e disparar o roteador novamente?)
      # Ou simplesmente mover para Shark Tank se a regra permitir.
      
      Rails.logger.info "[PocketExpirationJob] Lead #{lead_id} expirou no pocket. Redistribuindo..."
      
      lead.update!(status: :received, admin_user_id: nil)
      lead.activities.create!(kind: "pocket_expired", metadata: { previous_admin_user_id: lead.admin_user_id_was })
      
      # Forçamos uma nova rodada de distribuição
      Leads::RoutingService.new(lead).route!
    end
  end
end
