class PagesController < ActionController::Base
  def menu
    restaurant = Restaurant.find_by!(slug: params[:restaurant_slug])
    template = mobile_request? ? "docs/menu-mobile.html" : "docs/menu.html"
    render_html(template, restaurant)
  end

  def admin
    restaurant = Restaurant.find_by!(slug: params[:restaurant_slug])
    render_html("docs/admin.html", restaurant)
  end

  private

  def mobile_request?
    request.user_agent.to_s.match?(/Android|iPhone|iPad|iPod|Mobile|IEMobile|Opera Mini/i)
  end

  def render_html(file, restaurant)
    html = File.read(Rails.root.join(file))
    html = html.sub("<body", "<body data-restaurant-slug=\"#{ERB::Util.html_escape(restaurant.slug)}\"")
    self.content_type = "text/html"
    render html: html.html_safe, layout: false
  end
end