###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga
mixOf = @.taiga.mixOf


class AdminEpicSchedulesController extends mixOf(taiga.Controller, taiga.PageMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgConfirm",
        "$routeParams",
        "$tgUrls",
        "$tgHttp",
        "tgAppMetaService",
        "$translate",
        "tgErrorHandlingService",
        "tgProjectService",
        "$timeout",
        "$document"
    ]

    constructor: (@scope, @rootscope, @confirm, @params, @urls, @http, @appMetaService,
                  @translate, @errorHandlingService, @projectService, @timeout, @document) ->
        @scope.epics = []
        @scope.epicStatuses = []
        @scope.loading = false
        @scope.saving = {}

        @scope.isSaving          = @.isSaving.bind(@)
        @scope.schedulableToStr  = @.schedulableToStr.bind(@)
        @scope.onSchedulableChange = @.onSchedulableChange.bind(@)
        @scope.onStatusChange    = @.onStatusChange.bind(@)
        @scope.onFieldBlur       = @.onFieldBlur.bind(@)
        @scope.toggleStatus      = @.toggleStatus.bind(@)

        closeAllStatus = () =>
            @scope.$apply =>
                for epic in (@scope.epics or [])
                    epic._showStatus = false

        angular.element(@document).on('click', closeAllStatus)
        @scope.$on '$destroy', ->
            angular.element(@document).off('click', closeAllStatus)

        @scope.$on "project:load", () =>
            @projectService.fetchProject().then () =>
                @.loadProject()
                @.loadEpics()

        @.loadInitialData()

    loadProject: ->
        project = @projectService.project.toJS()

        if not project.i_am_admin
            @errorHandlingService.permissionDenied()

        @scope.projectId    = project.id
        @scope.project      = project
        @scope.epicStatuses = project.epic_statuses or []
        @scope.$emit('project:loaded', project)
        return project

    DATE_FIELDS = ['start_date', 'expected_completion_date', 'completion_date']

    _strToDate: (str) ->
        return null unless str
        return new Date(str + "T00:00:00")

    _dateToStr: (date) ->
        return null unless date
        return date.toISOString().split('T')[0]

    _snapshot: (epic) ->
        start_date:                epic.start_date
        expected_completion_date:  epic.expected_completion_date
        completion_date:           epic.completion_date
        percentage_impact:         epic.percentage_impact
        schedulable:               epic.schedulable
        _schedulable:              epic._schedulable
        status:                    epic.status
        status_extra_info:         angular.copy(epic.status_extra_info)

    loadEpics: ->
        @scope.loading = true
        url = @urls.resolve("epics")
        return @http.get(url, {project: @scope.projectId}, {"headers": {"x-disable-pagination": "1"}})
            .then (result) =>
                @scope.epics = result.data.map (epic) =>
                    for field in DATE_FIELDS
                        epic[field] = @._strToDate(epic[field])
                    epic.percentage_impact = if epic.percentage_impact? then parseInt(epic.percentage_impact, 10) else 0
                    epic._schedulable = @.schedulableToStr(epic.schedulable)
                    epic._snap = @._snapshot(epic)
                    epic
            .finally =>
                @scope.loading = false

    loadInitialData: ->
        @.loadProject()
        return @.loadEpics()

    patchEpic: (epic, patch) ->
        key = epic.id + '_' + Object.keys(patch)[0]
        @scope.saving[key] = true
        url = @urls.resolve("epics") + "/#{epic.id}"
        patch.version = epic.version

        return @http.patch(url, patch)
            .then (result) =>
                idx = @scope.epics.findIndex (e) -> e.id == epic.id
                if idx >= 0
                    updated = result.data
                    for field in DATE_FIELDS
                        updated[field] = @._strToDate(updated[field])
                    updated._schedulable = @.schedulableToStr(updated.schedulable)
                    updated.percentage_impact = if updated.percentage_impact? then parseFloat(updated.percentage_impact) else 0
                    angular.extend(@scope.epics[idx], updated)
                    @scope.epics[idx]._snap = @._snapshot(@scope.epics[idx])
                @timeout => @confirm.notify("success")
            .catch (response) =>
                for field of patch when field != 'version'
                    epic[field] = epic._snap?[field]
                    epic._schedulable = epic._snap?._schedulable if field == 'schedulable'
                    epic.status_extra_info = epic._snap?.status_extra_info if field == 'status'
                data = response?.data or {}
                rawCode = data.code
                rawCode = rawCode[0] if Array.isArray(rawCode)
                msg = if rawCode
                    @translate.instant("ERRORS.#{rawCode.toUpperCase()}")
                else if data._error_code
                    @translate.instant("ERRORS.#{data._error_code}")
                else
                    data._error_message or null
                @timeout => @confirm.notify("error", msg)
            .finally =>
                @scope.saving[key] = false

    isSaving: (epicId, field) ->
        return !!@scope.saving[epicId + '_' + field]

    schedulableToStr: (val) ->
        if val is true then 'yes'
        else if val is false then 'no'
        else 'na'

    onSchedulableChange: (epic) ->
        value = switch epic._schedulable
            when 'yes' then true
            when 'no'  then false
            else null
        @.patchEpic(epic, {schedulable: value})

    toggleStatus: (epic, $event) ->
        $event.stopPropagation()
        wasOpen = epic._showStatus
        for e in (@scope.epics or [])
            e._showStatus = false
        epic._showStatus = !wasOpen

    onStatusChange: (epic, status) ->
        epic.status = status.id
        epic.status_extra_info = {name: status.name, color: status.color, is_closed: status.is_closed}
        @.patchEpic(epic, {status: status.id})

    onFieldBlur: (epic, field) ->
        patch = {}
        value = epic[field]
        if value instanceof Date
            value = @._dateToStr(value)

        snapValue = epic._snap?[field]
        if snapValue instanceof Date
            snapValue = @._dateToStr(snapValue)
        return if value == snapValue

        if field == 'percentage_impact'
            if not Number.isInteger(value)
                epic[field] = epic._snap?[field]
                @timeout => @confirm.notify("error", @translate.instant("ERRORS.PERCENTAGE_IMPACT_MUST_BE_INTEGER"))
                return
            return if value == epic._snap?[field]
            if epic.schedulable == true
                otherSum = @scope.epics.reduce (acc, e) ->
                    if e.id != epic.id and e.schedulable == true then acc + (e.percentage_impact or 0) else acc
                , 0
                if otherSum + value > 100
                    epic[field] = epic._snap?[field]
                    @timeout => @confirm.notify("error", @translate.instant("ERRORS.SCHEDULABLE_IMPACT_EXCEEDS_100"))
                    return
        patch[field] = value
        @.patchEpic(epic, patch)


module = angular.module("taigaAdmin")
module.controller("AdminEpicSchedulesController", AdminEpicSchedulesController)
