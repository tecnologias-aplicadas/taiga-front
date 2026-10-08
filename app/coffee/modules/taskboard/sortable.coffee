###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga

mixOf = @.taiga.mixOf
toggleText = @.taiga.toggleText
scopeDefer = @.taiga.scopeDefer
bindOnce = @.taiga.bindOnce
groupBy = @.taiga.groupBy

module = angular.module("taigaBacklog")

#############################################################################
## Sortable Directive
#############################################################################

TaskboardSortableDirective = ($repo, $rs, $rootscope, $translate, $tgConfirm) ->
    link = ($scope, $el, $attrs) ->
        unwatch = $scope.$watch "usTasks", (usTasks) ->
            return if !usTasks || !usTasks.size

            unwatch()

            if not ($scope.project.my_permissions.indexOf("modify_task") > -1)
                return

            oldParentScope = null
            newParentScope = null
            itemEl = null
            tdom = $el
            initialContainer = null

            filterError = ->
                text = $translate.instant("BACKLOG.SORTABLE_FILTER_ERROR")
                $tgConfirm.notify("error", text)

            deleteElement = (itemEl) ->
                itemEl.off()
                itemEl.remove()

            containers = _.map $el.find('.taskboard-column'), (item) ->
                return item

            drake = dragula(containers, {
                copySortSource: false,
                copy: false,
                accepts: (el, target) -> 
                    return !$(target).hasClass('taskboard-row-title-box')
                moves: (item) ->
                    return $(item).is('tg-card')
            })

            drake.on 'shadow', (item) ->
                $(item).removeClass('folded-dragging')

            drake.on 'over', (item, container) ->
                if !initialContainer
                    initialContainer = container
                else if container != initialContainer
                    $(container).addClass('target-drop')

            drake.on 'out', (item, container) ->
                if container != initialContainer
                    $(container).removeClass('target-drop')

            drake.on 'drag', (item) ->
                oldParentScope = $(item).parent().scope()
                
                # Armazenar a posição original para possível restauração
                $(item).data('original-index', $(item).index())
                $(item).data('original-container', $(item).parent())

                if $(item).width() == 30
                    $(item).addClass('folded-dragging')

                if $el.hasClass("active-filters")
                    filterError()

                    setTimeout (() ->
                        drake.cancel(true)
                    ), 0

                    return false

            # Variável para controlar se o movimento foi cancelado
            moveCancelled = false
            
            # Adicionar estilo de transição se ainda não existir
            if !$('#card-transition-style').length
                $('head').append('<style id="card-transition-style">.card-transition{transition:transform 0.3s ease, opacity 0.3s ease;}</style>')
            
            drake.on 'drop', (item, target, source, sibling) ->
                oldParentScope = $(source).scope()
                newParentScope = $(target).scope()

                oldUsId = if oldParentScope.us then oldParentScope.us.id else null
                newUsId = if newParentScope.us then newParentScope.us.id else null

                if newUsId != oldUsId
                    # Marcar como cancelado
                    moveCancelled = true
                    
                    # Restaurar à posição original imediatamente
                    originalContainer = $(item).data('original-container')
                    originalIndex = $(item).data('original-index') || 0
                    
                    # Adicionar classe de transição para suavizar o retorno
                    $(item).addClass('card-transition')
                    
                    # Usar setTimeout para garantir que o DOM seja atualizado
                    setTimeout(() ->
                        # Remover o item do alvo
                        $(item).detach()
                        
                        # Reinserir na origem
                        if originalIndex == 0
                            $(source).prepend($(item))
                        else
                            $(source).children().eq(originalIndex - 1).after($(item))
                            
                        # Notificar o usuário
                        errorMsg = $translate.instant("TASKBOARD.ERROR_MOVE_TO_ANOTHER_US")
                        $tgConfirm.notify("error", errorMsg)
                        
                        # Remover classe de transição após a animação
                        setTimeout(() ->
                            $(item).removeClass('card-transition')
                        , 300)
                    , 0)
                    
                    return false


            drake.on 'dragend', (item) ->
                # Verificar se o movimento foi cancelado pelo evento drop
                if moveCancelled
                    moveCancelled = false
                    return
                    
                parentEl = $(item).parent()
                itemEl = $(item)
                itemTask = $scope.taskMap.get(Number(item.dataset.id))
                itemIndex = itemEl.index()
                newParentScope = parentEl.scope()

                oldUsId = if oldParentScope.us then oldParentScope.us.id else null
                oldStatusId = oldParentScope.st.id
                newUsId = if newParentScope.us then newParentScope.us.id else null
                newStatusId = newParentScope.st.id

                # Verificar novamente se mudou de história (caso o evento drop não tenha sido acionado)
                if newUsId != oldUsId
                    return

                if initialContainer != parentEl
                    $(parentEl).addClass('new')
                    $(parentEl).one 'animationend', () ->
                        $(parentEl).removeClass('new')

                if newStatusId != oldStatusId
                    deleteElement(itemEl)

                scopeDefer $scope, ->
                    tableBody = $('.taskboard-table-body')
                    tableBody.addClass('moving')

                    setTimeout () ->
                        tableBody.removeClass('moving')
                    , 1000

                    $rootscope.$broadcast(
                        "taskboard:task:move",
                        itemTask,
                        newStatusId,
                        newUsId,
                        newStatusId,
                        itemIndex
                    )

            scroll = autoScroll([$('.taskboard-table-body')[0]], {
                margin: 100,
                pixels: 30,
                scrollWhenOutside: true,
                autoScroll: () ->
                    return this.down && drake.dragging
            })

            $scope.$on "$destroy", ->
                $el.off()
                drake.destroy()

    return {link: link}


module.directive("tgTaskboardSortable", [
    "$tgRepo",
    "$tgResources",
    "$rootScope",
    "$translate",
    "$tgConfirm",
    TaskboardSortableDirective
])