###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

FavItemDirective = ->
    link = (scope, el, attrs, ctrl) ->
        scope.vm = {item: scope.item}

        # História lê só a lista múltipla (já ordenada por id pelo servidor);
        # épica, tarefa e issue seguem no campo único.
        scope.vm.getAssignedUser = () ->
            return null if not scope.vm.item

            if scope.vm.item.get('type') == "userstory"
                assignedUsers = scope.vm.item.get('assigned_users_extra_info')
                return null if not assignedUsers or assignedUsers.size == 0
                return assignedUsers.first()

            return scope.vm.item.get('assigned_to_extra_info') or null

        # Quantos atribuídos além do exibido; só história tem lista múltipla.
        scope.vm.getExtraAssigneesCount = () ->
            return 0 if not scope.vm.item or scope.vm.item.get('type') != "userstory"

            assignedUsers = scope.vm.item.get('assigned_users_extra_info')
            return 0 if not assignedUsers or assignedUsers.size < 2
            return assignedUsers.size - 1

    templateUrl = (el, attrs) ->
        if attrs.itemType == "project"
            return "profile/profile-favs/items/project.html"
        else # if attr.itemType in ["userstory", "task", "issue"]
            return "profile/profile-favs/items/ticket.html"

    return {
        scope: {
            "item": "=tgFavItem"
        }
        link: link
        templateUrl: templateUrl
    }


angular.module("taigaProfile").directive("tgFavItem", FavItemDirective)
