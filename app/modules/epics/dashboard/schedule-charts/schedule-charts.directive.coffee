###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

ScheduleChartsDirective = ($timeout) ->
    link = (scope, el, attrs, ctrl) ->
        ctrl.el = el[0]
        $timeout () ->
            ctrl.loadData()

    return {
        templateUrl: "epics/dashboard/schedule-charts/schedule-charts.html"
        controller: "ScheduleChartsCtrl"
        controllerAs: "vm"
        link: link
    }

ScheduleChartsDirective.$inject = ['$timeout']

angular.module('taigaEpics').directive('tgScheduleCharts', ScheduleChartsDirective)
