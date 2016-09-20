# handles administrative tasks for the collection object
class CollectionController < ApplicationController

  public :render_to_string

  protect_from_forgery :except => [:set_collection_title,
                                   :set_collection_intro_block,
                                   :set_collection_footer_block]

  before_filter :authorized?, :only => [:new, :edit, :update, :delete]
  before_filter :load_settings, :only => [:edit, :update]

  # no layout if xhr request
  layout Proc.new { |controller| controller.request.xhr? ? false : nil }, :only => [:new, :create]

  def authorized?
    
    unless user_signed_in?
      ajax_redirect_to dashboard_path
    end

    if @collection &&  !current_user.like_owner?(@collection)
      ajax_redirect_to dashboard_path
    end
  end

  def enable_document_sets
    @collection.supports_document_sets = true
    @collection.save!
    redirect_to({ :controller => 'document_sets', :action => 'index', :collection_id => @collection.id })# { :controller => 'document_sets', :action => 'index', :collection_id => @collection.id }
  end

  def load_settings
    @main_owner = @collection.owner
    @owners = [@main_owner] + @collection.owners
    @nonowners = User.order(:display_name) - @owners
    @nonowners.each { |user| user.display_name = user.login if user.display_name.empty? }
    @works_not_in_collection = current_user.owner_works - @collection.works
  end

  def show
    @users = User.all
    @top_ten_transcribers = build_user_array(Deed::PAGE_TRANSCRIPTION)
    @top_ten_editors      = build_user_array(Deed::PAGE_EDIT)
    @top_ten_indexers     = build_user_array(Deed::PAGE_INDEXED)
  end

  def owners
    @main_owner = @collection.owner
    @owners = @collection.owners + [@main_owner]
    @nonowners = User.all - @owners
  end

  def add_owner
    @collection.owners << @user
    redirect_to action: 'edit', collection_id: @collection.id
  end

  def remove_owner
    @collection.owners.delete(@user)
    redirect_to action: 'edit', collection_id: @collection.id
  end

  def publish_collection
    @collection.restricted = false
    @collection.save!
    redirect_to action: 'edit', collection_id: @collection.id
  end

  def restrict_collection
    @collection.restricted = true
    @collection.save!
    redirect_to action: 'edit', collection_id: @collection.id
  end

  def delete
    @collection.destroy
    redirect_to dashboard_owner_path
  end

  def new
    @collection = Collection.new
  end

  def edit
  end

  def update
    if @collection.update_attributes(params[:collection])
      flash[:notice] = 'Collection has been updated'
      redirect_to action: 'edit', collection_id: @collection.id
    else
      render action: 'edit'
    end
  end

  # tested
  def create
    @collection = Collection.new
    @collection.title = params[:collection][:title]
    @collection.intro_block = params[:collection][:intro_block]
    @collection.owner = current_user
    if @collection.save
      flash[:notice] = 'Collection has been created'
      ajax_redirect_to({ action: 'edit', collection_id: @collection.id })
    else
      render action: 'new'
    end
  end

  def add_work_to_collection
    logger.debug("DEBUG collection1=#{@collection}")
    set_collection_for_work(@collection, @work)
    logger.debug("DEBUG collection2=#{@collection}")
    redirect_to action: 'edit', collection_id: @collection.id
  end

  def remove_work_from_collection
    set_collection_for_work(nil, @work)
    redirect_to action: 'edit', collection_id: @collection.id
  end

def contributors
  @collection = Collection.find_by(id: params[:collection_id])

  #set variables
  trans_type = ["page_trans", "page_edit"]
  note_type = "note_add"
  article_type = "art_edit"
  translate_type = ["pg_xlat", "pg_xlat_ed"]
  condition = "created_at >= ? AND created_at <= ?"

  #Get the start and end date params from date picker, if none, set defaults
  start_date = params[:start_date]
  end_date = params[:end_date]
  
  if start_date == nil
    start_date = 1.week.ago
    end_date = Time.now.utc
  end

  start_date = start_date.to_datetime
  end_date = end_date.to_datetime

  @start_deed = start_date.strftime("%b %d, %Y")
  @end_deed = end_date.strftime("%b %d, %Y")

  #find the deeds of each type in the collection
  transcription_deeds = @collection.deeds.where(deed_type: trans_type)
  note_deeds = @collection.deeds.where(deed_type: note_type)
  article_deeds = @collection.deeds.where(deed_type: article_type)
  translate_deeds = @collection.deeds.where(deed_type: translate_type)
  
  #find deeds for the date range
  @recent_notes = note_deeds.where(condition, start_date, end_date)
  @recent_transcriptions = transcription_deeds.where(condition, start_date, end_date)
  @recent_articles = article_deeds.where(condition, start_date, end_date)
  @recent_translations = translate_deeds.where(condition, start_date, end_date)

  #get distinct user ids per deed and create list of users
  user_deeds = transcription_deeds.distinct.pluck(:user_id)
  @all_transcribers = User.where(id: user_deeds)

  #find recent transcription deeds by user, then older deeds by user
  recent_trans_deeds = @recent_transcriptions.distinct.pluck(:user_id)
  recent_users = User.where(id: recent_trans_deeds)
  older_trans_deeds = transcription_deeds.where("created_at < ?", start_date).distinct.pluck(:user_id)
  older_users = User.where(id: older_trans_deeds)

  #compare older to recent list to get new transcribers
  @new_transcribers = recent_users - older_users
  
end

private
  def set_collection_for_work(collection, work)
    # first update the id on the work
    work.collection = collection
    work.save!
    # then update the id on the articles
    # consider moving this to the work model?
    for article in work.articles
      article.collection = collection
      article.save!
    end
  end

  def build_user_array(deed_type)
    user_array = []
    condition = "collection_id = ? AND deed_type = ?"
    deeds_by_user = Deed.group('user_id').where([condition, @collection.id, deed_type]).limit(10).order('count_id desc').count('id')
    deeds_by_user.each { |user_id, count| user_array << [ @users.find { |u| u.id == user_id }, count ] }
    return user_array
  end

end