class MtController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id, :authorize, :get_trackers
  menu_item :traceability

  def index
    @issue_rows = @tracker_rows.issues.where(:project_id => @project.id).order(:id)

    @issue_cols = @tracker_cols.issues.where(:project_id => @project.id).order(:id)

    relations = IssueRelation.joins('INNER JOIN issues issue_from ON issue_from.id = issue_relations.issue_from_id ' +
                                             'INNER JOIN issues issue_to ON issue_to.id = issue_relations.issue_to_id ') #:issue_from, :issue_to)
                              .where("issue_from.project_id = ? 
                                      AND issue_to.project_id = ?
                                      AND ((issue_from.tracker_id = ? AND issue_to.tracker_id = ?)
                                      OR (issue_from.tracker_id = ? AND issue_to.tracker_id = ?))", @project.id, @project.id, @tracker_rows.id, @tracker_cols.id, @tracker_cols.id, @tracker_rows.id)

    @not_seen_issue_cols = @issue_cols.deep_dup
    @issue_pairs = {}
    relations.each do |relation|
      if relation.issue_from.tracker_id == @tracker_rows.id
        @issue_pairs[relation.issue_from] ||= {}
        @issue_pairs[relation.issue_from][relation.issue_to] ||= []
        @issue_pairs[relation.issue_from][relation.issue_to] << true     
        @not_seen_issue_cols = @not_seen_issue_cols.reject{|i| i==relation.issue_to}
      else
        @issue_pairs[relation.issue_to] ||= {}
        @issue_pairs[relation.issue_to][relation.issue_from] ||= []
        @issue_pairs[relation.issue_to][relation.issue_from] << true
        @not_seen_issue_cols = @not_seen_issue_cols.reject{|i| i==relation.issue_from}
      end
    end

    return unless @tracker_int

    int_to_rows = {}
    # Lookup intermediate tracker issue relations
    @relations_issue = IssueRelation.joins('INNER JOIN issues issue_from ON issue_from.id = issue_relations.issue_from_id ' +
                                           'INNER JOIN issues issue_to ON issue_to.id = issue_relations.issue_to_id ')
                                    .where("issue_from.project_id = ? 
                                            AND issue_to.project_id = ?
                                            AND ((issue_from.tracker_id = ? AND issue_to.tracker_id = ?)
                                                OR (issue_from.tracker_id = ? AND issue_to.tracker_id = ?))", @project.id, @project.id, @tracker_rows.id, @tracker_int.id, @tracker_int.id, @tracker_rows.id)

    @relations_issue.each do |relation|
      if relation.issue_from.tracker_id == @tracker_int.id
        int_to_rows[relation.issue_from] ||= []
        int_to_rows[relation.issue_from] << relation.issue_to
      else
        int_to_rows[relation.issue_to] ||= []
        int_to_rows[relation.issue_to] << relation.issue_from
      end
    end

    @relations_issue = IssueRelation.joins('INNER JOIN issues issue_from ON issue_from.id = issue_relations.issue_from_id ' +
                                           'INNER JOIN issues issue_to ON issue_to.id = issue_relations.issue_to_id ')
                                    .where("issue_from.project_id = ?
                                            AND issue_to.project_id = ?
                                            AND ((issue_from.tracker_id = ? AND issue_to.tracker_id = ?) 
                                                  OR (issue_from.tracker_id = ? AND issue_to.tracker_id = ?))", @project.id, @project.id, @tracker_cols.id, @tracker_int.id, @tracker_int.id, @tracker_cols.id)

    @relations_issue.each do |relation|
      if relation.issue_from.tracker_id == @tracker_int.id
        if int_to_rows.has_key? relation.issue_from
          int_to_rows[relation.issue_from].each do |row_issue|
            @issue_pairs[row_issue] ||= {}
            @issue_pairs[row_issue][relation.issue_to] ||= []
            @issue_pairs[row_issue][relation.issue_to] << relation.issue_from
            @not_seen_issue_cols = @not_seen_issue_cols.reject{|i| i==relation.issue_to}
          end
        end
      else
        if int_to_rows.has_key? relation.issue_to
          int_to_rows[relation.issue_to].each do |row_issue|
            @issue_pairs[row_issue] ||= {}
            @issue_pairs[row_issue][relation.issue_from] ||= []
            @issue_pairs[row_issue][relation.issue_from] << relation.issue_to
            @not_seen_issue_cols = @not_seen_issue_cols.reject{|i| i==relation.issue_from}
          end
        end
      end
    end

  end

  private

  def get_trackers
    @tracker_rows = Tracker.find(Setting.plugin_redmine_traceability['tracker0'])
    @tracker_cols = Tracker.find(Setting.plugin_redmine_traceability['tracker1'])
    if Setting.plugin_redmine_traceability['tracker2'].present?
      @tracker_int = Tracker.where(:id => Setting.plugin_redmine_traceability['tracker2'].to_i).first
    end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = l(:'traceability.setup')
    render
  end
end
