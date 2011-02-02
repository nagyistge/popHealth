class MeasuresController < ApplicationController
  include RailsWarden::Mixins::HelperMethods
  include RailsWarden::Mixins::ControllerOnlyMethods
  before_filter :set_up_environment
  before_filter :authenticate!
  
  def index
    @selected_measures = mongo['selected_measures'].find({:username => user.username}).to_a #need to call to_a so that it isn't a cursor
    @grouped_selected_measures = @selected_measures.group_by {|measure| measure['category']}
    @categories = Measure.non_core_measures
    @core_measures = Measure.core_measures
    @core_alt_measures = Measure.core_alternate_measures
    render 'dashboard'
  end
    
  def result
    @result = @executor.measure_result(params[:id], params[:sub_id], :effective_date=> @effective_date)
    
    render :json => @result
  end

  def definition
    @definition = @executor.measure_def(params[:id], params[:sub_id])
    
    render :json => @definition
  end

  def show
    @definition = @executor.measure_def(params[:id], params[:sub_id])
    
    render 'measure'
  end
  
  def patients
    @result = @executor.measure_result(params[:id], params[:sub_id], :effective_date=> @effective_date)
    @definition = @executor.measure_def(params[:id], params[:sub_id])
  end
  
  def measure_patients
    @result = @executor.measure_result(params[:id], params[:sub_id], :effective_date=> @effective_date)
    type = params[:type] || "denominator"
   
    @limit = (params[:limit] || 20).to_i
    @skip = ((params[:page] || 1).to_i - 1 ) * @limit
    sort = params[:sort] || "_id"
    sort_order = params[:sort_order] || :asc
    measure_id = params[:id] 
    sub_id = params[:sub_id]
    cache_name =  "cached_measure_patients_#{measure_id}_#{sub_id}_#{@effective_date}"
    @records = mongo[cache_name].find({:measure_id => measure_id, :sub_id => sub_id,
                                       :effective_date => @effective_date, type => true}, 
                                      {:sort => [sort, sort_order], :skip => @skip, :limit => @limit}).to_a
    @total =  mongo[cache_name].find({:measure_id => measure_id, :sub_id => sub_id,
                                      :effective_date => @effective_date, type => true}).count

    @page_results = WillPaginate::Collection.create((params[:page] || 1), @limit, @total) do |pager|
       pager.replace(@records)
    end

  end

  def select
    measure = Measure.add_measure(user.username, params[:id])
    
    results = {:patient_count => mongo['records'].count}
    if measure['subs'].empty?
      results[measure['id']] = @executor.measure_result(params[:id], nil, :effective_date=> @effective_date)
    else
      measure['subs'].each do |sub_id|
        results[measure['id'] + sub_id] = @executor.measure_result(params[:id], sub_id, :effective_date=> @effective_date)
      end
    end
    render :partial => 'measure_stats', :locals => {:measure => measure, :results => results}
  end
  
  def remove
    Measure.remove_measure(user.username, params[:id])
    render :text => 'Removed'
  end

  private
  
  def set_up_environment
    @executor = QME::MapReduce::Executor.new(mongo)
    @patient_count = mongo['records'].count
    
    @effective_date = Time.gm(2010, 12, 31).to_i
  end

end
