# Bootstrap global da plataforma. Dados de demonstração ficam em `bin/rails demo:seed`.
email = ENV.fetch("PLATFORM_OWNER_EMAIL", "AdminControl@pedeai.dev").to_s.strip.downcase
password = ENV.fetch("PLATFORM_OWNER_PASSWORD", "pedeaiDev").to_s
name = ENV.fetch("PLATFORM_OWNER_NAME", "PedeAi Owner")

if email.blank? || password.blank?
  puts "Platform owner not changed: set PLATFORM_OWNER_EMAIL and PLATFORM_OWNER_PASSWORD."
else
  owner = PlatformUser.find_or_initialize_by(email: email)
  owner.assign_attributes(name: name, role: "owner", active: true)
  owner.password = password
  owner.password_confirmation = password
  owner.save!
  puts "Platform owner ready: #{owner.email}"
end
