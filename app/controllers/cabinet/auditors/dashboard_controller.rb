# frozen_string_literal: true

module Cabinet
  module Auditors
    class DashboardController < BaseController
      def index
        @pending_count = NotVerifiedAdvisorySheet.where(auditor: current_auditor).count
        @verified_count = VerifiedAdvisorySheet.where(auditor: current_auditor).count

        if VerifiedAdvisorySheet.exists?
          @stats = {
            red: VerifiedAdvisorySheet.where(auditor: current_auditor).red.count,
            yellow: VerifiedAdvisorySheet.where(auditor: current_auditor).yellow.count,
            green: VerifiedAdvisorySheet.where(auditor: current_auditor).green.count
          }
        else
          @stats = { red: 0, yellow: 0, green: 0 }
        end
      end
    end
  end
end
