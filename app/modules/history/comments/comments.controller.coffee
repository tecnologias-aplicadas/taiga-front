###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaHistory")

class CommentsController
  @.$inject = ["$tgHttp", "$scope", "$tgUrls"]

  constructor: (@$tgHttp, @$scope, @$urls) ->
    @canAddCommentPermission = null
    @__reactionsLoaded = false
    @loadingReactions = {}

    @$scope.$watchCollection (=> @comments), (newVal) =>
      return unless newVal?.length
      return if @__reactionsLoaded

      @__reactionsLoaded = true
      for c in newVal
        @loadReactionsForComment(c.id)

  loadReactionsForComment: (commentId) ->
      comment = _.find(@comments or [], (c) -> c.id == commentId)
      unless comment
          return

      url = @$urls.resolve("comment-reactions-list", commentId)
      @$tgHttp.get(url).then (res) =>
          comment.reactions = res.data or {}

  editCommentAndReloadReactions: (commentId, commentData, callback) ->
      url = @$urls.resolve("comment-edit", commentId)
      payload = { comment: commentData }

      @$tgHttp.post(url, payload).then (res) =>
          comment = _.find(@comments or [], (c) -> c.id == commentId)
          if comment
              comment.comment = res.data.comment
              comment.edit_comment_date = res.data.edit_comment_date

          @loadReactionsForComment(commentId)
          callback?()

  handleEditComment: (commentId, commentData, callback) ->
      @editCommentAndReloadReactions(commentId, commentData, callback)

  initializePermissions: ->
      @canAddCommentPermission = "comment_" + @name

module.controller "CommentsCtrl", CommentsController
