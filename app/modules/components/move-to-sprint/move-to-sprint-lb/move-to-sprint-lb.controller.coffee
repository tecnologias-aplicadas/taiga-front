###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaComponents")

ACHIEVEMENT_OPTIONS = [
    {value: 'achieved', labelKey: 'TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.ACHIEVED'}
    {value: 'partially_achieved', labelKey: 'TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.PARTIALLY_ACHIEVED'}
    {value: 'not_achieved', labelKey: 'TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.NOT_ACHIEVED'}
]

# Keys the API uses for field errors on close_with_result, in display order.
FIELD_ERROR_KEYS = ['goal_achievement', 'result', 'milestone_id']

class MoveToSprintLightboxController
    @.$inject = [
        '$rootScope'
        '$scope'
        '$tgResources'
        'tgProjectService'
        'lightboxService'
        '$tgConfirm'
    ]

    constructor: (
        @rootScope
        @scope
        @rs
        @projectService
        @lightboxService
        @confirm
    ) ->
        @.projectId = @projectService.project.get('id')
        @.loading = false
        @.hasOpenItems = false
        @.sprints = null
        @.selectedSprintId = null
        @.achievementOptions = ACHIEVEMENT_OPTIONS
        @.result = {
            goal_achievement: null
            result: ''
        }

        @scope.$watch (() => @.openItems), (openItems) =>
            return if !openItems
            @._init(openItems)

    _init: (openItems) ->
        @.ussCount = openItems.uss?.length or 0
        @.tasksCount = openItems.tasks?.length or 0
        @.issuesCount = openItems.issues?.length or 0
        @.hasOpenItems = (@.ussCount + @.tasksCount + @.issuesCount) > 0

        # The destination sprint only matters when the server will have to move
        # something, so the list is fetched only in that case.
        @._loadSprints() if @.hasOpenItems

    _loadSprints: () ->
        @rs.sprints.list(@.projectId, {closed: false}).then (data) =>
            @.sprints = _.filter(data.milestones, (x) => x.id != @.sprint.id)

    hasGoal: () ->
        return _.trim(@.sprint?.goal or '').length > 0

    hasNoDestination: () ->
        return @.hasOpenItems and @.sprints? and @.sprints.length == 0

    isResultFilled: () ->
        achievementOk = _.some(ACHIEVEMENT_OPTIONS, (option) => option.value == @.result.goal_achievement)
        return achievementOk and _.trim(@.result.result or '').length > 0

    canSubmit: () ->
        return false if @.loading
        # The server refuses to close a sprint with nothing finished (400);
        # the button only anticipates it. hasClosedItems comes from the board.
        return false if not @.hasClosedItems
        return false if not @.isResultFilled()
        return false if @.hasOpenItems and not @.selectedSprintId?
        return true

    submit: () ->
        return if not @.canSubmit()

        data = {
            goal_achievement: @.result.goal_achievement
            result: _.trim(@.result.result)
        }
        data.milestone_id = @.selectedSprintId if @.hasOpenItems

        @.loading = true

        onSuccess = (response) =>
            @.loading = false
            # The board reloads the sprint from the API (closed, result and the
            # items that were moved), the same way it does after moving items.
            @rootScope.$broadcast("taskboard:items:move", {uss: true, tasks: true, issues: true})
            @lightboxService.closeAll()

        onError = (response) =>
            @.loading = false
            @confirm.notify("error", @._errorMessage(response))

        return @rs.sprints.closeWithResult(@.sprint.id, data).then(onSuccess, onError)

    _errorMessage: (response) ->
        data = response?.data or {}
        return data._error_message if data._error_message
        return data.detail if data.detail
        for key in FIELD_ERROR_KEYS
            return data[key][0] if _.isArray(data[key]) and data[key].length
        return undefined

module.controller("MoveToSprintLbCtrl", MoveToSprintLightboxController)
