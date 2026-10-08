###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga

ACHIEVEMENTS = {
    achieved: {cssClass: 'achieved', labelKey: 'ACHIEVED'}
    partially_achieved: {cssClass: 'partially-achieved', labelKey: 'PARTIALLY_ACHIEVED'}
    not_achieved: {cssClass: 'not-achieved', labelKey: 'NOT_ACHIEVED'}
}

NOT_INFORMED_ACHIEVEMENT = {cssClass: 'not-informed', labelKey: 'NOT_INFORMED'}

class SprintGoalController
    @.$inject = [
        '$scope'
        '$tgStorage'
        '$translate'
        'tgCurrentUserService'
        'tgProjectService'
        'tgLightboxFactory'
    ]

    constructor: (@scope, @storage, @translate, @currentUserService, @projectService, @lightboxFactory) ->
        @.isExpanded = false

        @scope.$watch (() => @.sprint?.id), () => @.loadExpandedState()

    storageKey: () ->
        userId = @currentUserService.getUser()?.get('id') or null
        return taiga.generateHash(["sprint-goal-expanded", userId, @.sprint.id])

    loadExpandedState: () ->
        if not @.sprint?.id
            @.isExpanded = false
            return

        @.isExpanded = @storage.get(@.storageKey()) is true

    toggle: () ->
        return if not @.sprint?.id

        @.isExpanded = !@.isExpanded
        @storage.set(@.storageKey(), @.isExpanded)

    hasGoal: () ->
        return _.trim(@.sprint?.goal or '').length > 0

    hasResult: () ->
        return @.sprint?.result?

    achievement: () ->
        return ACHIEVEMENTS[@.sprint?.goal_achievement] or NOT_INFORMED_ACHIEVEMENT

    achievementClass: () ->
        return @.achievement().cssClass

    achievementLabelKey: () ->
        return "TASKBOARD.SPRINT_GOAL.ACHIEVEMENT.#{@.achievement().labelKey}"

    resultAuthorName: () ->
        authorId = @.sprint?.result_by
        return null if not authorId?

        member = @projectService.project?.get('members')?.find (member) -> member.get('id') == authorId
        return member?.get('full_name_display') or null

    resultDate: () ->
        return null if not @.sprint?.result_date

        return moment(@.sprint.result_date).format(@translate.instant('COMMON.DATETIME'))

    notInformed: () ->
        return @translate.instant('TASKBOARD.SPRINT_GOAL.NOT_INFORMED')

    resultAuthorLabel: () ->
        return @.resultAuthorName() or @.notInformed()

    resultDateLabel: () ->
        return @.resultDate() or @.notInformed()

    # A sprint closed by the inherited rule (last open item closed or deleted)
    # never went through the "Close sprint" lightbox, so it has no result. The
    # server decides who may register it (modify_milestone) and refuses a
    # repeated registration; the button only mirrors that.
    canRegisterResult: () ->
        return false if not @.sprint?.id
        return false if @.sprint.closed isnt true
        return false if @.hasResult()
        permissions = @projectService.project?.get('my_permissions')
        return permissions? and permissions.indexOf('modify_milestone') != -1

    openRegisterResult: () ->
        return if not @.canRegisterResult()

        # Same lightbox as "Close sprint", in register-only mode: no open items
        # to move, and the closed sprint has at least one closed item by rule.
        @lightboxFactory.create('tg-lb-move-to-sprint', {
            "class": "lightbox lightbox-move-to-sprint"
            "sprint": "sprint"
            "open-items": "openItems"
            "has-closed-items": "hasClosedItems"
            "register-only": "registerOnly"
        }, {
            sprint: @.sprint
            openItems: {}
            hasClosedItems: true
            registerOnly: true
        })

angular.module('taigaComponents').controller('SprintGoalCtrl', SprintGoalController)
