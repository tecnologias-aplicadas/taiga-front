###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module('taigaBase')

class DetailHeaderController
    @.$inject = [
        "$rootScope",
        "$tgConfirm",
        "$tgQueueModelTransformation",
        "$tgNavUrls",
        "$window",
        "tgEditingTracker"
    ]

    EDITING_KEY = "detail-header-subject"

    constructor: (@rootScope, @confirm, @modelTransform, @navUrls, @window, @editingTracker) ->
        @.editMode = false
        @.loadingSubject = false
        @.originalSubject = @.item.subject
        @.objType = {
            'tasks': 'task',
            'issues': 'issue',
            'userstories': 'us',
        }[@.item._name]

    _checkPermissions: () ->
        @.permissions = {
            canEdit: _.includes(@.project.my_permissions, @.requiredPerm)
        }

    cancelEdit: () ->
        @.editMode = false
        @editingTracker.end(EDITING_KEY)
        @.item.subject = @.originalSubject

    editSubject: (value) ->
        selection = @window.getSelection()
        if selection.type != "Range"
            if value
                @.editMode = true
                @editingTracker.begin(EDITING_KEY)
            if !value
                @.editMode = false
                @editingTracker.end(EDITING_KEY)

    onKeyDown: (event) ->
        if event.which == 13
            @.saveSubject()

        if event.which == 27
            @.item.subject = @.originalSubject
            @.editSubject(false)

    saveSubject: () ->
        onEditSubjectSuccess = () =>
            @.loadingSubject = false
            @rootScope.$broadcast("object:updated")
            @confirm.notify('success')
            @.originalSubject = @.item.subject

        onEditSubjectError = () =>
            @.loadingSubject = false
            @confirm.notify('error')

        @.editMode = false
        @editingTracker.end(EDITING_KEY)
        @.loadingSubject = true
        item = @.item
        transform = @modelTransform.save (item) ->
            return item
        return transform.then(onEditSubjectSuccess, onEditSubjectError)

module.controller("DetailHeaderCtrl", DetailHeaderController)
