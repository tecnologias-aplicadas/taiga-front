###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

class EpicRowController
    @.$inject = [
        "$scope",
        "$tgConfirm",
        "tgProjectService",
        "tgEpicsService",
        "$translate"
    ]
    
    constructor: (@$scope, @confirm, @projectService, @epicsService, @translate) ->
        
        @.displayUserStories = false
        @.displayAssignedTo = false
        @.displayStatusList = false
        @.loadingStatus = false
        @.loadingStartDate = false
        @.loadingExpectedCompletionDate = false
        @.loadingCompletionDate = false
        @.schedulableValue = @._schedulableToString(@.epic.get('schedulable'))
        # NOTE: We use project as no inmutable object to make
        #       the code compatible with the old code
        @.project = @projectService.project.toJS()

        # A lista foi recarregada por evento do servidor: histórias expandidas são cópia própria
        @$scope.$on "epics:refreshed", =>
            @.reloadUserStoryList() if @.displayUserStories

        @.canModify =  @projectService.hasPermission("modify_epic")

        @._calculateProgressBar()
        @._initialDateSetter()
        @._calculateDateLimits()

        updateProgress = =>
            @_calculateProgressBar()

        @$scope.$watch () =>
            @epic?.get('completion_percent_done')
        , updateProgress

        @$scope.$watch () =>
            @epic?.get('completion_percent_progress')
        , updateProgress
        

    _calculateProgressBar: () ->

        donePercent = parseFloat(@.epic.get('completion_percent_done')) or 0
        progressPercent = parseFloat(@.epic.get('completion_percent_progress')) or 0

        @.segments = []

        # Caso 0%
        if donePercent == 0 and progressPercent == 0
            @.segments.push
                width: "100%"
                left: "0%"
                color: "#bfbfbf"
                type: "empty"
                name: @translate.instant("EPICS.NOT_STARTED")
                percentage: "0.00"
            return

        # Concluído
        if donePercent > 0
            @.segments.push
                width: "#{donePercent}%"
                left: "0%"
                color: "#6994EA"
                type: "done"
                name: @translate.instant("EPICS.DONE")
                percentage: donePercent.toFixed(2)

        # Em progresso
        if progressPercent > 0
            @.segments.push
                width: "#{progressPercent}%"
                left: "#{donePercent}%"
                color: "#e48a46"
                type: "progress"
                name: @translate.instant("EPICS.PROGRESS")
                percentage: progressPercent.toFixed(2)

    textDateFormatter: (dateToFormat) ->
        return moment(dateToFormat).format('DD/MM/YYYY')

    _initialDateSetter: () ->
        if @.epic.get('start_date') 
            @.startDate = new Date(@.epic.get('start_date') + "T00:00:00")
        if @.epic.get('expected_completion_date') 
            @.expectedCompletionDate = new Date(@.epic.get('expected_completion_date') + "T00:00:00")
        if @.epic.get('completion_date') 
            @.completionDate = new Date(@.epic.get('completion_date') + "T00:00:00")


    _calculateDateLimits: () ->
        @.startDateMin = new Date('2000-01-01')

        limitDate = null

        # compara completionDate e expectedCompletionDate para setar a data menor como limite do input da startDate
        if @.completionDate and @.expectedCompletionDate
            limitDate = if @.completionDate < @.expectedCompletionDate then @.completionDate else @.expectedCompletionDate
        else if @.completionDate
            limitDate = @.completionDate
        else if @.expectedCompletionDate
            limitDate = @.expectedCompletionDate

        # startDate pode ser igual à data limite (mesmo dia permitido)
        @.calculatedStartDateMax = if limitDate then new Date(limitDate) else null

        # expectedCompletionDate pode ser igual à startDate (mesmo dia permitido)
        @.calculatedMinAllowedDate = if @.startDate then new Date(@.startDate) else null


    canEditEpics: () ->
        return @projectService.hasPermission("modify_epic")

    toggleUserStoryList: () ->
        if !@.displayUserStories
            @epicsService.listRelatedUserStories(@.epic)
                .then (userStories) =>
                    @.epicStories = userStories
                    @.displayUserStories = true
                .catch =>
                    @confirm.notify('error')
        else
            @.displayUserStories = false

    reloadUserStoryList: () ->
        return @epicsService.listRelatedUserStories(@.epic)
            .then (userStories) =>
                @.epicStories = userStories

    _resetStartDate: () ->
        @.startDate = if @.epic.get('start_date') then new Date(@.epic.get('start_date') + "T00:00:00") else null

    _resetExpectedCompletionDate: () ->
        @.expectedCompletionDate = if @.epic.get('expected_completion_date') then new Date(@.epic.get('expected_completion_date') + "T00:00:00") else null

    _isInvalidDate: (date) ->
        return !date or isNaN(date.getTime())

    _isStartDateValid: () ->
        return false if @._isInvalidDate(@.startDate)
        return false if @.startDateMin and @.startDate < @.startDateMin
        return false if @.calculatedStartDateMax and @.startDate > @.calculatedStartDateMax
        return true

    _isExpectedCompletionDateValid: () ->
        return false if @._isInvalidDate(@.expectedCompletionDate)
        return false if @.calculatedMinAllowedDate and @.expectedCompletionDate < @.calculatedMinAllowedDate
        return true

    _notifyError: (response) ->
        data = response?.data or {}
        rawCode = data.status?[0] or data.code or null
        rawCode = rawCode[0] if Array.isArray(rawCode)
        if rawCode
            @confirm.notify('error', @translate.instant("ERRORS.#{rawCode.toUpperCase()}"))
        else
            @confirm.notify('error')

    blurStartDate: () ->
        if not @._isStartDateValid()
            @._resetStartDate()
            @.startDateError = null
            @.startDateBorderAlert = null
            @confirm.notify('error', @translate.instant('ERRORS.START_DATE_EXCEEDS_END_DATE'))
            return

        formattedDate = @.startDate.toISOString().split('T')[0]
        return if formattedDate == (@.epic.get('start_date') or null)

        @.startDateError = null
        @.startDateBorderAlert = null
        @epicsService.updateEpicDate(@.epic, 0, formattedDate)
            .then () =>
                @.expectedCompletionDateError = null
                @.expectedCompletionDateBorderAlert = null
                @._calculateDateLimits()
                @confirm.notify('success')
            .catch (response) =>
                @._resetStartDate()
                @._calculateDateLimits()
                @._notifyError(response)

    blurExpectedCompletionDate: () ->
        if not @._isExpectedCompletionDateValid()
            @._resetExpectedCompletionDate()
            @.expectedCompletionDateError = null
            @.expectedCompletionDateBorderAlert = null
            @confirm.notify('error', @translate.instant('ERRORS.END_DATE_BEFORE_START_DATE'))
            return

        formattedDate = @.expectedCompletionDate.toISOString().split('T')[0]
        return if formattedDate == (@.epic.get('expected_completion_date') or null)

        @.expectedCompletionDateError = null
        @.expectedCompletionDateBorderAlert = null
        @epicsService.updateEpicDate(@.epic, 1, formattedDate)
            .then () =>
                @.startDateError = null
                @.startDateBorderAlert = null
                @._calculateDateLimits()
                @confirm.notify('success')
            .catch (response) =>
                @._resetExpectedCompletionDate()
                @._calculateDateLimits()
                @._notifyError(response)
        
    updateStatus: (statusId) ->
        @.displayStatusList = false
        @.loadingStatus = true
        return @epicsService.updateEpicStatus(@.epic, statusId)
            .catch (response) =>
                @._notifyError(response)
            .finally () =>
                @.loadingStatus = false
                
    # ── Schedulable read-only display ─────────────────────────────────────────
    _schedulableToString: (val) ->
        if val is true then 'yes'
        else if val is false then 'no'
        else 'na'

    schedulableClass: () ->
        switch @.schedulableValue
            when 'yes' then 'is-yes'
            when 'no'  then 'is-no'
            else 'is-na'

    schedulableLabel: () ->
        switch @.schedulableValue
            when 'yes' then @translate.instant('EPICS.TABLE.SCHEDULABLE_YES')
            when 'no'  then @translate.instant('EPICS.TABLE.SCHEDULABLE_NO')
            else 'N/A'

    updateAssignedTo: (member) ->
        @.assignLoader = true
        return @epicsService.updateEpicAssignedTo(@.epic, member?.id or null)
            .catch () =>
                @confirm.notify('error')
            .then () =>
                @.assignLoader = false

angular.module("taigaEpics").controller("EpicRowCtrl", EpicRowController)

