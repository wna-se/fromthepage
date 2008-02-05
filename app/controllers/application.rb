# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require_dependency "login_system"

class ApplicationController < ActionController::Base
  include AuthenticatedSystem
  before_filter :load_objects_from_params
  before_filter :set_current_user_in_model


  def load_objects_from_params

    # this needs to be ordered from the specific to the
    # general, so that parent_id will load the appropriate
    # object without being overridden by child_id.parent
    # whenever both are specified on the parameters
    if params[:article_id]
      @article = Article.find(params[:article_id])
      @collection = @article.collection
    end
    if params[:page_id]
      @page = Page.find(params[:page_id])
      @work = @page.work
      @collection = @work.collection
    end
    if params[:work_id]
      @work = Work.find(params[:work_id])
      @collection = @work.collection
    end
    if params[:collection_id]
      @collection = Collection.find(params[:collection_id])
    end

    # image stuff is orthogonal to collections
    if params[:titled_image_id]
      @titled_image = TitledImage.find(params[:titled_image_id])
      @image_set = @titled_image.image_set
    end
    if params[:image_set_id]
      @image_set = ImageSet.find(params[:image_set_id])
    end
    if params[:user_id]
      @user = User.find(params[:user_id])
    end
    
    # category stuff may be orthogonal to collections and articles
    if params[:category_id]
      @category = Category.find(params[:category_id])
    end

    # consider loading work and collection from the versions
    if params[:page_version_id]
      @page_version = PageVersion.find(params[:page_version_id])
      @page = @page_version.page
      @work = @page.work
      @collection = @work.collection
    end
    if params[:article_version_id]
      @article_version = ArticleVersion.find(params[:article_version_id])
      @article = @article_version.article
      @collection = @article.collection
    end
  end
  
  # Set the current user in User
  def set_current_user_in_model
    User.current_user = current_user
  end 

end