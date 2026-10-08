###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaComponents")

sprintGoalDirective = () ->
    return {
        restrict: "A"
        controller: "SprintGoalCtrl"
        controllerAs: "sprintGoal"
        scope: true
        bindToController: {
            sprint: "=tgSprintGoal"
        }
    }

module.directive("tgSprintGoal", [sprintGoalDirective])
