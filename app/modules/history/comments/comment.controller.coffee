###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaHistory")

class CommentController
    @.$inject = [
        "tgCurrentUserService",
        "tgCheckPermissionsService",
        "tgLightboxFactory",
        "$tgHttp",
        "$tgUrls",
        "$rootScope"
    ]

    constructor: (@currentUserService, @permissionService, @lightboxFactory, @$tgHttp, @$urls, @$rootScope) ->
        @.hiddenDeletedComment = true
        @._tooltipsGenerated = false
        
    $doCheck: ->
        if !@._tooltipsGenerated and @comment?.reactions
            @._tooltipsGenerated = true
            @pregenerateTooltips()


    showDeletedComment: () ->
        @.hiddenDeletedComment = false

    hideDeletedComment: () ->
        @.hiddenDeletedComment = true

    checkCancelComment: (event) ->
        if event.keyCode == 27
            @.onEditMode({commentId: @.comment.id})

    canEditDeleteComment: () ->
        if @currentUserService.getUser()
            @.user = @currentUserService.getUser()
            return @.user.get('id') == @.comment.user.pk || @permissionService.check('modify_project')

    saveComment: (text, cb) ->
        unless @onEditComment
            cb?()
            return
        try
            @onEditComment({
                commentId: @.comment.id
                commentData: text
                callback: =>
                    cb?()
            })
        catch error
            cb?()

    displayCommentHistory: () ->
        @lightboxFactory.create('tg-lb-display-historic', {
            "class": "lightbox lightbox-display-historic"
            "comment": "comment"
            "name": "name"
            "object": "object"
        }, {
            "comment": @.comment
            "name": @.name
            "object": @.object
        })

    reactWithEmoji: ({ emoji, commentId }) ->
        url = @$urls.resolve("comment-add-reaction", commentId)
        payload = { emoji }
        @$tgHttp.post(url, payload).then (res) =>

            @.comment.reactions ?= {}

            if @.comment.reactions[emoji]
                @.comment.reactions[emoji].count += 1
                @.comment.reactions[emoji].users.push(@currentUserService.getUser().get("id"))
            else
                @.comment.reactions[emoji] = {
                    count: 1
                    users: [@currentUserService.getUser().get("id")]
                }
            @pregenerateTooltips()


    toggleReaction: (emoji) ->
        userId = @currentUserService.getUser().get("id")
        existing = @.comment.reactions?[emoji]?.users or []

        if userId in existing
            @removeReaction(emoji)
        else
            @reactWithEmoji({ "emoji": emoji, commentId: @.comment.id })

    removeReaction: (emoji) ->
        url = @$urls.resolve("comment-remove-reaction", @.comment.id)
        payload = { emoji }

        @$tgHttp.delete(url, payload).then (res) =>

            reaction = @.comment.reactions[emoji]
            return unless reaction

            reaction.count -= 1

            user = @currentUserService.getUser()
            if reaction.users and user
                reaction.users = reaction.users.filter (id) ->
                    id isnt user.get("id")

            if reaction.count <= 0
                delete @.comment.reactions[emoji]

            @pregenerateTooltips()
            @$rootScope.$applyAsync()


    pregenerateTooltips: ->
        return unless @comment?.reactions

        usersById = _.keyBy(@activeUsers, (u) -> u.get?("id") or u.id)

        for emoji, data of @comment.reactions
            data.tooltip = (data.users or []).map((id) ->
                user = usersById[id]
                user?.get?("full_name_display") or user?.full_name_display or "Usuário ##{id}"
            ).join("\n")


module.controller("CommentCtrl", CommentController)
