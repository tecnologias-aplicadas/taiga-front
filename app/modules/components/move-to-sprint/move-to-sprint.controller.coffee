###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga

class MoveToSprintController
    @.$inject = [
      '$scope'
      'tgLightboxFactory'
      'tgProjectService'
    ]

    constructor: (
        @scope
        @lightboxFactory
        @projectService
    ) ->
        @.permissions = @projectService.project.get('my_permissions')
        @.hasOpenItems = false
        @.hasClosedItems = false
        @.disabled = false
        @.openItems = {
            uss: []
            tasks: []
            issues: []
        }
        # The server refuses to close a sprint with nothing finished; the
        # lightbox warns before the click, reading the same lists as openItems.
        @.closedItems = {
            uss: false
            tasks: false
            issues: false
        }

        @scope.$watch "vm.uss", () => @getOpenUss()
        @scope.$watch "vm.unnasignedTasks", () => @getOpenStorylessTasks()
        @scope.$watch "vm.issues", () => @getOpenIssues()

    checkOpenItems: () ->
        return _.some(Object.keys(@.openItems), (x) => @.openItems[x].length > 0)

    checkClosedItems: () ->
        return _.some(Object.keys(@.closedItems), (x) => @.closedItems[x])

    # The server decides who closes a sprint (modify_milestone) and refuses a
    # sprint already closed or with a result already registered (a reopened
    # sprint keeps its result); the button only mirrors that so the user does
    # not open a lightbox that will be refused anyway.
    canCloseSprint: () ->
        return false if @.permissions.indexOf("modify_milestone") == -1
        return false if not @.sprint?
        return false if @.sprint.result?
        return @.sprint.closed isnt true

    openLightbox: () ->
        if @.disabled is not true && @.canCloseSprint()
            openItems = {}
            _.map @.openItems, (itemsList, itemsType) ->
                if itemsList.length
                    openItems[itemsType] = itemsList

            @lightboxFactory.create('tg-lb-move-to-sprint', {
                "class": "lightbox lightbox-move-to-sprint"
                "sprint": "sprint"
                "open-items": "openItems"
                "has-closed-items": "hasClosedItems"
            }, {
                sprint: @.sprint
                openItems: openItems
                hasClosedItems: @.hasClosedItems
            })

    getOpenUss: () ->
        return if !@.uss or @.permissions.indexOf("modify_us") == -1
        @.openItems.uss = []
        @.closedItems.uss = false
        @.uss.map (us) =>
            if us.is_closed is false
                @.openItems.uss.push({
                    us_id: us.id
                    order: us.sprint_order
                })
            else if us.is_closed is true
                @.closedItems.uss = true
        @.hasOpenItems = @checkOpenItems()
        @.hasClosedItems = @checkClosedItems()

    getOpenStorylessTasks: () ->
        return if !@.unnasignedTasks or @.permissions.indexOf("modify_task") == -1
        @.openItems.tasks = []
        @.closedItems.tasks = false
        @.unnasignedTasks.map (column) => column.map (taskId) =>
            task = @.taskMap.get(taskId)
            if task.get('model').get('is_closed') is false
                @.openItems.tasks.push({
                    task_id: task.get('model').get('id')
                    order: task.get('model').get('taskboard_order')
                })
            else if task.get('model').get('is_closed') is true
                @.closedItems.tasks = true
        @.hasOpenItems = @checkOpenItems()
        @.hasClosedItems = @checkClosedItems()

    getOpenIssues: () ->
        return if !@.issues or @.permissions.indexOf("modify_issue") == -1
        @.openItems.issues = []
        @.closedItems.issues = false
        @.issues.map (issue) =>
            if issue.get('status').get('is_closed') is false
                @.openItems.issues.push({ issue_id: issue.get('id') })
            else if issue.get('status').get('is_closed') is true
                @.closedItems.issues = true
        @.hasOpenItems = @checkOpenItems()
        @.hasClosedItems = @checkClosedItems()

angular.module('taigaComponents').controller('MoveToSprintCtrl', MoveToSprintController)
