FactoryBot.define do
  factory :audit do
    consultation_sheet { nil }
    auditor { nil }
    analysis { "" }
  end
end
