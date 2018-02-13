class GroupsController < BaseController
  layout 'darkswarm'

  def index
    @groups = EnterpriseGroup.on_front_page.by_position
  end

  def show
    enable_embedded_shopfront
    @hide_menu = true if @shopfront_layout == 'embedded'
    @group = EnterpriseGroup.find_by_permalink(params[:id]) || EnterpriseGroup.find(params[:id])
    @large_columns = "large-9"
    @target = "_self"

    return nil unless params[:embedded_shopfront]
    @large_columns = "large-12"
    @target = "_blank"
  end
end
