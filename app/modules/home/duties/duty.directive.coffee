###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

DutyDirective = (navurls, $translate) ->
    link = (scope, el, attrs, ctrl) ->
        scope.vm = {}
        scope.vm.duty = scope.duty
        scope.vm.type = scope.type
        scope.vm.isHidden = scope.isHidden

        scope.vm.getDutyType = () ->
            if scope.vm.duty
                if scope.vm.duty.get('_name') == "epics"
                    return $translate.instant("COMMON.EPIC")
                if scope.vm.duty.get('_name') == "userstories"
                    return $translate.instant("COMMON.USER_STORY")
                if scope.vm.duty.get('_name') == "tasks"
                    return $translate.instant("COMMON.TASK")
                if scope.vm.duty.get('_name') == "issues"
                    return $translate.instant("COMMON.ISSUE")

        # História lê só a lista múltipla (já ordenada por id pelo servidor);
        # épica, tarefa e issue seguem no campo único.
        scope.vm.getAssignedUser = () ->
            return null if not scope.vm.duty

            if scope.vm.duty.get('_name') == "userstories"
                assignedUsers = scope.vm.duty.get('assigned_users_extra_info')
                return null if not assignedUsers or assignedUsers.size == 0
                return assignedUsers.first()

            return scope.vm.duty.get('assigned_to_extra_info') or null

        # Quantos atribuídos além do exibido; só história tem lista múltipla.
        scope.vm.getExtraAssigneesCount = () ->
            return 0 if not scope.vm.duty or scope.vm.duty.get('_name') != "userstories"

            assignedUsers = scope.vm.duty.get('assigned_users_extra_info')
            return 0 if not assignedUsers or assignedUsers.size < 2
            return assignedUsers.size - 1

        el.on "click", ".button-hide", (event) ->
            event.preventDefault()
            el.remove()
            scope.$emit('duty:toggle-hidden', scope.vm.duty, scope.vm.type)

    return {
        templateUrl: "home/duties/duty.html"
        scope: {
            "duty": "=tgDuty",
            "isHidden": "=",
            "type": "@"
        }
        link: link
    }

DutyDirective.$inject = [
    "$tgNavUrls",
    "$translate"
]

angular.module("taigaHome").directive("tgDuty", DutyDirective)
