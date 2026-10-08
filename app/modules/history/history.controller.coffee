###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaHistory")

class HistorySectionController
    @.$inject = [
        "$tgResources",
        "$tgRepo",
        "$tgStorage",
        "tgProjectService",
        "tgActivityService",
        "tgWysiwygService",
        "tgCommentsReactionsService"
    ]

    constructor: (@rs, @repo, @storage, @projectService, @activityService, @wysiwygService, @commentsReactionsService) ->
        @.editing = null
        @.deleting = null
        @.editMode = {}
        @.viewComments = true

        @.reverse = @storage.get("orderComments")
        @.activeUsers = []
        taiga.defineImmutableProperty @, 'disabledActivityPagination', () =>
            return @activityService.disablePagination
        taiga.defineImmutableProperty @, 'loadingActivity', () =>
            return @activityService.loading
    
    _loadActiveUsers: ->
        return unless @project?.id
        @rs.projects.usersList(@project.id).then (users) =>
            active = _.filter(users, (u) -> u.is_active)
            @activeUsers = _.sortBy(active, "full_name_display")

    $onInit: ->
        @._loadActiveUsers()

    _loadHistory: () ->
        if @.totalComments == 0
            @.commentsNum = 0
        else
            @._loadComments()

        @._loadActivity()

    _loadActivity: () ->
        @activityService.init(@.name, @.id)
        @activityService.fetchEntries().then (response) =>
            @.activitiesNum = @activityService.count
            @.activities = response.toJS()

    _loadComments: () ->
        # Salvar as reações de todos os comentários antes de recarregar
        if @.comments?.length
            @commentsReactionsService.storeAllReactions(@.comments)
        
        @rs.history.get(@.name, @.id, 'comment').then (comments) =>
            @.comments = _.filter(comments, (item) -> item.comment != "")
            
            # Restaurar as reações para todos os comentários
            @commentsReactionsService.restoreAllReactions(@.comments)
            
            if @.reverse
                @.comments = _.reverse(@.comments)
            @.commentsNum = @.comments.length

    nextActivityPage: () ->
        @activityService.nextPage().then (response) =>
            @.activities = response.toJS()

    showHistorySection: () ->
        return @.showCommentTab() or @.showActivityTab()

    showCommentTab: () ->
        return @.commentsNum > 0 or @projectService.hasPermission("comment_#{@.name}")

    showActivityTab: () ->
        return @.activitiesNum > 0

    toggleEditMode: (commentId) ->
        @.editMode[commentId] = !@.editMode[commentId]

    onActiveHistoryTab: (active) ->
        @.viewComments = active

    deleteComment: (commentId) ->
        type = @.name
        objectId = @.id
        activityId = commentId
        @.deleting = commentId
        return @rs.history.deleteComment(type, objectId, activityId).then =>
            @._loadComments()
            @.deleting = null

    editComment: (commentId, comment) ->
        type = @.name
        objectId = @.id
        activityId = commentId
        @.editing = commentId
        
        # Salvar as reações de todos os comentários antes da edição
        if @.comments?.length
            @commentsReactionsService.storeAllReactions(@.comments)
        
        return @rs.history.editComment(type, objectId, activityId, comment).then =>
            # Recarregar comentários diretamente em vez de chamar @._loadComments()
            @rs.history.get(@.name, @.id, 'comment').then (comments) =>
                @.comments = _.filter(comments, (item) -> item.comment != "")
                
                # Restaurar as reações para todos os comentários
                @commentsReactionsService.restoreAllReactions(@.comments)
                
                if @.reverse
                    @.comments = _.reverse(@.comments)
                @.commentsNum = @.comments.length
                
                # Finalizar edição
                @.toggleEditMode(commentId)
                @.editing = null

    restoreDeletedComment: (commentId) ->
        type = @.name
        objectId = @.id
        activityId = commentId
        @.editing = commentId
        return @rs.history.undeleteComment(type, objectId, activityId).then =>
            @._loadComments()
            @.editing = null

    addComment: () ->
        # Salvar as reações de todos os comentários antes de adicionar um novo
        if @.comments?.length
            @commentsReactionsService.storeAllReactions(@.comments)
            
        @.editMode = {}
        @.editing = null
        @._loadComments()

    onOrderComments: () ->
        @.reverse = !@.reverse
        @storage.set("orderComments", @.reverse)
        @._loadComments()

module.controller("HistorySection", HistorySectionController)
