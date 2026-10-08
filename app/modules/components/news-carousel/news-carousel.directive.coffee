###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

# Carrossel de novidades da home pública: lê /news (público) e porta o
# comportamento que antes era um script inline na home (loop infinito com
# clones do primeiro e do último slide, setas, pontos, arraste, contador,
# anel de progresso e troca automática). Engloba a seção inteira: sem slide
# ativo ou sem resposta do servidor, nada é renderizado.

SLIDE_DURATION = 5500
RING_CIRCUMFERENCE = 94.2
TRACK_TRANSITION = "transform .95s cubic-bezier(.77,0,.18,1)"

NewsCarouselDirective = ($rs, $timeout) ->
    link = (scope, el, attrs) ->
        vm = scope.vm = {
            loading: true
            slides: []
            track: []
            total: 0
            current: 0
        }

        pos = 1
        autoTimer = null
        dragging = false
        startX = 0
        delta = 0

        trackEl = () -> el.find(".hl-cw-track")
        ringEl = () -> el.find(".hl-cw-ring-fill")

        setTransform = (value, animated) ->
            track = trackEl()
            track.css("transition", if animated then TRACK_TRANSITION else "none")
            track.css("transform", value)

        startRing = () ->
            ring = ringEl()
            ring.css("transition", "none")
            ring.css("stroke-dashoffset", RING_CIRCUMFERENCE)
            $timeout.cancel(autoTimer) if autoTimer

            return if vm.total < 2

            window.requestAnimationFrame () ->
                window.requestAnimationFrame () ->
                    ring.css("transition", "stroke-dashoffset #{SLIDE_DURATION}ms linear")
                    ring.css("stroke-dashoffset", 0)

            autoTimer = $timeout((() -> vm.go(vm.current + 1)), SLIDE_DURATION)
            return

        vm.go = (n, animated = true) ->
            return if vm.total == 0
            vm.current = ((n % vm.total) + vm.total) % vm.total
            pos = if vm.total > 1 then n + 1 else 0
            setTransform("translateX(-#{pos * 100}%)", animated)
            startRing()
            return

        vm.next = () ->
            vm.go(vm.current + 1)
            return

        vm.prev = () ->
            vm.go(vm.current - 1)
            return

        # Ao terminar a transição num clone, reposiciona sem animar
        onTransitionEnd = () ->
            return if vm.total < 2
            if pos == 0
                pos = vm.total
                setTransform("translateX(-#{pos * 100}%)", false)
            if pos == vm.total + 1
                pos = 1
                setTransform("translateX(-#{pos * 100}%)", false)

        onPointerDown = (event) ->
            return if vm.total < 2
            dragging = true
            startX = event.clientX
            delta = 0
            trackEl().css("transition", "none")
            event.currentTarget.setPointerCapture?(event.pointerId)

        onPointerMove = (event) ->
            return if not dragging
            delta = event.clientX - startX
            trackEl().css("transform", "translateX(calc(-#{pos * 100}% + #{delta}px))")

        onPointerUp = () ->
            return if not dragging
            dragging = false
            scope.$evalAsync () ->
                if Math.abs(delta) > 60
                    vm.go(if delta < 0 then vm.current + 1 else vm.current - 1)
                else
                    vm.go(vm.current)

        bindStage = () ->
            stage = el.find(".hl-cw-stage")
            track = trackEl()
            track.on("transitionend", onTransitionEnd)
            stage.on("pointerdown", (e) -> onPointerDown(e.originalEvent or e))
            stage.on("pointermove", (e) -> onPointerMove(e.originalEvent or e))
            stage.on("pointerup pointercancel", onPointerUp)

        showNothing = () ->
            vm.loading = false
            vm.slides = []
            vm.track = []
            vm.total = 0

        showSlides = (slides) ->
            vm.loading = false
            vm.slides = slides
            vm.total = slides.length
            if vm.total > 1
                vm.track = [slides[vm.total - 1]].concat(slides, [slides[0]])
            else
                vm.track = slides.slice()
            # espera o ng-repeat renderizar antes de posicionar e ligar os eventos
            # (sem devolver a promise do $timeout, para não atrelar a cadeia do list() ao timer)
            $timeout () ->
                bindStage()
                vm.go(0, false)
            return

        $rs.news.list()
            .then (slides) ->
                if _.isArray(slides) and slides.length
                    showSlides(slides)
                else
                    showNothing()
            .catch () ->
                showNothing()

        scope.$on "$destroy", () ->
            $timeout.cancel(autoTimer) if autoTimer
            el.find(".hl-cw-stage").off()
            trackEl().off()

    return {
        restrict: "E"
        scope: {}
        templateUrl: "components/news-carousel/news-carousel.html"
        link: link
    }

NewsCarouselDirective.$inject = [
    "$tgResources",
    "$timeout"
]

angular.module("taigaComponents").directive("tgNewsCarousel", NewsCarouselDirective)
