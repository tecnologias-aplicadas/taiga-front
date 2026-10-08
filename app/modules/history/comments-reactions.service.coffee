###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

class CommentsReactionsService
    constructor: () ->
        @reactionsCache = {}
        
    # Armazena as reações de um comentário
    storeReactions: (commentId, reactions) ->
        if reactions
            @reactionsCache[commentId] = _.cloneDeep(reactions)
            # console.log "💾 CommentsReactionsService: Reações armazenadas para comentário", commentId
        
    # Armazena as reações de vários comentários
    storeAllReactions: (comments) ->
        if comments?.length
            for comment in comments
                if comment?.reactions
                    @reactionsCache[comment.id] = _.cloneDeep(comment.reactions)
            # console.log "💾 CommentsReactionsService: Reações armazenadas para", Object.keys(@reactionsCache).length, "comentários"
        
    # Recupera as reações armazenadas para um comentário
    getStoredReactions: (commentId) ->
        return @reactionsCache[commentId]
        
    # Restaura as reações em todos os comentários
    restoreAllReactions: (comments) ->
        if comments?.length
            restoredCount = 0
            for comment in comments
                if @reactionsCache[comment.id]
                    comment.reactions = _.cloneDeep(@reactionsCache[comment.id])
                    restoredCount++
        
    # Limpa o cache de reações
    clearCache: ->
        @reactionsCache = {}
        console.log "🗑️ CommentsReactionsService: Cache de reações limpo"

angular.module("taigaHistory")
    .service("tgCommentsReactionsService", CommentsReactionsService)