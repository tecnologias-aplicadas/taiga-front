###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaEpics")

class RelatedUserstoryRowController
    @.$inject = [
        "tgProjectService",
        "tgAvatarService",
        "$translate",
        "$tgConfirm",
        "tgResources"
    ]

    constructor: (@projectService, @avatarService, @translate, @confirm, @rs) ->

    # Atribuídos exibíveis: assigned_users em ordem crescente de id (o servidor
    # devolve um conjunto), só os que são membros ativos. O campo único
    # assigned_to não é fonte para tela de história.
    getAssignedMembers: () ->
        assignedUserIds = @.userstory.get('assigned_users')
        return Immutable.List() if not assignedUserIds or assignedUserIds.size == 0

        activeMembers = @projectService.activeMembers
        return assignedUserIds
            .sort()
            .map((id) -> activeMembers.find((member) -> member.get('id') == id))
            .filter((member) -> member?)

    getAssignedMember: () ->
        return @.getAssignedMembers().first() or null

    setAvatarData: () ->
        members = @.getAssignedMembers()
        @.avatar = @avatarService.getAvatar(members.first() or null)
        @.extraAssigneesCount = Math.max(members.size - 1, 0)

    getAssignedToFullNameDisplay: () ->
        member = @.getAssignedMember()
        if member
            return member.get('full_name_display')

        return @translate.instant("COMMON.ASSIGNED_TO.NOT_ASSIGNED")

    onDeleteRelatedUserstory: () ->
        title = @translate.instant("LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.TITLE")
        message = @translate.instant(
            "LIGHTBOX.REMOVE_RELATIONSHIP_WITH_EPIC.MESSAGE",
            { epicSubject: @.epic.get('subject') }
        )

        return @confirm.ask(title, null, message)
            .then (askResponse) =>
                onError = () =>
                    message = @translate.instant('EPIC.ERROR_UNLINK_RELATED_USERSTORY', {errorMessage: message})
                    @confirm.notify("error", null, message)
                    askResponse.finish(false)

                onSuccess = () =>
                    @.loadRelatedUserstories()
                    askResponse.finish()

                epicId = @.epic.get('id')
                userstoryId = @.userstory.get('id')
                @rs.epics.deleteRelatedUserstory(epicId, userstoryId).then(onSuccess, onError)

module.controller("RelatedUserstoryRowCtrl", RelatedUserstoryRowController)
