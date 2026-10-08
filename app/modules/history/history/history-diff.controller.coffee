###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

module = angular.module("taigaHistory")

class ActivitiesDiffController
    @.$inject = [
        "$translate" # Busca textos no arquivo de tradução
        "$sce"       # Usado para renderizar HTML seguro para os links clicáveis
    ]

    constructor: (@$translate, @$sce) ->

    buildCardUrl: (type, ref) ->
        typeMap =
            userstory: "us"
            task: "task"
            issue: "issue"
            epic: "epic"

        # Usamos o slug do projeto porque a rota do front da Taiga depende dele
        projectSlug = @.model?.project_extra_info?.slug or @.model?.project?.slug
        typeSlug = typeMap[type]

        return null unless projectSlug?
        return null unless typeSlug?
        return null unless ref?

        # Retorna a URL interna da Taiga para abrir a atividade relacionada
        return "/project/#{projectSlug}/#{typeSlug}/#{ref}"

    # Se houver URL válida, transforma o texto (#97) em link clicável.
    # Se não houver URL, devolve apenas o texto puro.
    buildRelationLink: (url, label) ->
        return label unless url
        return "<a class='relation-link' href='#{url}'>#{label}</a>"

    # Traduz a frase completa e depois substitui os números por links 
    buildRelationHtml: (translationKey, values) ->
        html = @$translate.instant(translationKey, values)

        if values.source_link?
            html = html.replace("__SOURCE_LINK__", values.source_link)

        if values.target_link?
            html = html.replace("__TARGET_LINK__", values.target_link)

        return @$sce.trustAsHtml(html) #Aqui estamos garantindo ao AngularJS que é um HTML confiável sendo inserido. 

    #Obtém dados de cada relacionamento para a utilização
    getRelationContext: (relation) ->
        sourceRef = "#" + relation.source_ref
        targetRef = "#" + relation.target_ref

        sourceKind = @$translate.instant("ACTIVITY.CARD_TYPES." + relation.source_type)
        targetKind = @$translate.instant("ACTIVITY.CARD_TYPES." + relation.target_type)

        sourceUrl = @.buildCardUrl(relation.source_type, relation.source_ref)
        targetUrl = @.buildCardUrl(relation.target_type, relation.target_ref)

        sourceLink = @.buildRelationLink(sourceUrl, sourceRef)
        targetLink = @.buildRelationLink(targetUrl, targetRef)

        return {
            sourceRef: sourceRef
            targetRef: targetRef
            sourceKind: sourceKind
            targetKind: targetKind
            sourceUrl: sourceUrl
            targetUrl: targetUrl
            sourceLink: sourceLink
            targetLink: targetLink
        }

    # Monta o HTML da activity quando a relação foi criada.
    buildCreatedRelationHtml: (relation, context) ->
        return @.buildRelationHtml(
            "ACTIVITY.RELATIONSHIP_" + relation.relation_type,
            {
                source_kind: context.sourceKind
                source: "__SOURCE_LINK__"
                target_kind: context.targetKind
                target: "__TARGET_LINK__"
                source_link: context.sourceLink
                target_link: context.targetLink
            }
        )

    # Monta o HTML da activity quando a relação é alterada.
    buildUpdatedRelationHtml: (beforeRelation, afterRelation, context) ->
        oldRelationLabel = @$translate.instant("ACTIVITY.RELATION." + beforeRelation.relation_type)
        newRelationLabel = @$translate.instant("ACTIVITY.RELATION." + afterRelation.relation_type)

        return @.buildRelationHtml(
            "ACTIVITY.RELATIONSHIP_CHANGED",
            {
                source_kind: context.sourceKind
                source: "__SOURCE_LINK__"
                target_kind: context.targetKind
                target: "__TARGET_LINK__"
                from: oldRelationLabel
                to: newRelationLabel
                source_link: context.sourceLink
                target_link: context.targetLink
            }
        )

    # Monta o HTML da activity quando a relação foi removida/resolvida.
    buildRemovedRelationHtml: (relation, context) ->
        relationLabel = @$translate.instant("ACTIVITY.RELATION." + relation.relation_type)
        i18nKey = if relation.action == "removed" then "ACTIVITY.RELATIONSHIP_REMOVED" else "ACTIVITY.RELATIONSHIP_RESOLVED"

        return @.buildRelationHtml(
            i18nKey,
            {
                source_kind: context.sourceKind
                source: "__SOURCE_LINK__"
                target_kind: context.targetKind
                target: "__TARGET_LINK__"
                relation: relationLabel
                source_link: context.sourceLink
                target_link: context.targetLink
            }
        )

    diffTags: () ->
        if @.type == 'tags'
            @.diffRemoveTags = _.difference(@.diff[0], @.diff[1]).toString()
            @.diffAddTags = _.difference(@.diff[1], @.diff[0]).toString()

        else if @.type == 'promoted_to'
            diff = _.difference(@.diff[1], @.diff[0])
            @.promotedTo = _.filter(@.model.generated_user_stories, (x) => _.includes(diff, x.id))

        else if @.type == 'card_relation'
            beforeRelation = @.diff?[0] # Estado antigo da relação
            afterRelation = @.diff?[1]  # Estado novo da relação

            # CREATE
            if !beforeRelation and afterRelation
                context = @.getRelationContext(afterRelation)

                @.relationMode = "created"
                @.relationType = afterRelation.relation_type
                @.relationClass = "relation-" + afterRelation.relation_type

                @.sourceRef = context.sourceRef
                @.targetRef = context.targetRef
                @.sourceKind = context.sourceKind
                @.targetKind = context.targetKind
                @.sourceUrl = context.sourceUrl
                @.targetUrl = context.targetUrl

                @.relationHtml = @.buildCreatedRelationHtml(afterRelation, context)

            # UPDATE
            else if beforeRelation and afterRelation
                context = @.getRelationContext(afterRelation)

                @.relationMode = "updated"
                @.relationClass = "relation-" + afterRelation.relation_type

                @.oldRelationType = beforeRelation.relation_type
                @.newRelationType = afterRelation.relation_type

                @.sourceRef = context.sourceRef
                @.targetRef = context.targetRef
                @.sourceKind = context.sourceKind
                @.targetKind = context.targetKind
                @.sourceUrl = context.sourceUrl
                @.targetUrl = context.targetUrl

                @.relationHtml = @.buildUpdatedRelationHtml(beforeRelation, afterRelation, context)

            # REMOVE / RESOLVE
            else if beforeRelation and !afterRelation
                context = @.getRelationContext(beforeRelation)

                @.relationMode = "removed"
                @.relationType = beforeRelation.relation_type
                @.relationClass = "relation-" + beforeRelation.relation_type

                @.sourceRef = context.sourceRef
                @.targetRef = context.targetRef
                @.sourceKind = context.sourceKind
                @.targetKind = context.targetKind
                @.sourceUrl = context.sourceUrl
                @.targetUrl = context.targetUrl

                @.relationHtml = @.buildRemovedRelationHtml(beforeRelation, context)

module.controller("ActivitiesDiffCtrl", ActivitiesDiffController)