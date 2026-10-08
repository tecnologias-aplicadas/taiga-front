###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaEpics")

class StoryRowController
    @.$inject = ["tgProjectService", "tgAvatarService", "$translate"]

    constructor: (@projectService, @avatarService, @translate) ->
        @._buildAssignedUsersDisplay()
        @._calculateProgressBar()
        @._calculateTasksInfo()

    _calculateTasksInfo: () ->
        tasks = @.story.get('tasks')
        if tasks && tasks.size > 0
            completedTasks = tasks.filter((task) -> task.get('is_closed')).size
            @.tasksInfo = @translate.instant("EPICS.TASKS_INFO", {
                completed: completedTasks
                total: tasks.size
            })
        else
            @.tasksInfo = @translate.instant("EPICS.TASKS_INFO", {
                completed: 0
                total: 0
            })

    _buildAssignedUsersDisplay: () ->
        assignedUserIds = @.story.get('assigned_users')

        if not assignedUserIds or assignedUserIds.size == 0
            @.assignedUsersDisplay = []
            @.extraAssigneesCount = 0
            return

        membersById = {}
        @projectService.activeMembers.forEach (member) ->
            membersById[member.get('id')] = member

        # Só assigned_users conta, em ordem crescente de id (o servidor devolve um
        # conjunto); id que não é membro ativo é descartado e não entra no
        # contador. O campo único assigned_to não é fonte nem reserva.
        assignedMembers = assignedUserIds
            .sort()
            .filter((id) -> membersById[id]?)
            .map((id) -> membersById[id])

        totalCount = assignedMembers.size
        maxVisible = if totalCount == 2 then 2 else 1

        @.assignedUsersDisplay = assignedMembers
            .slice(0, maxVisible)
            .map((member) => @avatarService.getAvatar(member))
            .toJS()

        @.extraAssigneesCount = if totalCount > 2 then totalCount - 1 else 0

    _calculateProgressBar: () ->

        done = parseFloat(@.story.get('completion_percent_done')) || 0
        progress = parseFloat(@.story.get('completion_percent_progress')) || 0

        @.donePercentage = "#{done}%"
        @.progressPercentage = "#{progress}%"

        @.segments = []

        # Caso 0%
        if done == 0 and progress == 0
            @.segments.push
                width: "100%"
                left: "0%"
                color: "#bfbfbf"
                type: "empty"
                name: @translate.instant("EPICS.NOT_STARTED")
                percentage: "0.00"
            return

        # Concluído
        if done > 0
            @.segments.push
                width: "#{done}%"
                left: "0%"
                color: "#6994ea"
                type: "done"
                name: @translate.instant("EPICS.DONE")
                percentage: done.toFixed(2)

        # Em progresso
        if progress > 0
            @.segments.push
                width: "#{progress}%"
                left: "#{done}%"
                color: "#e48a46"
                type: "progress"
                name: @translate.instant("EPICS.PROGRESS")
                percentage: progress.toFixed(2)

module.controller("StoryRowCtrl", StoryRowController)
