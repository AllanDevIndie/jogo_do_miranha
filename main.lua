if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local Assets = require("assets")
local Player = require("player")
local Enemies = require("enemies")
local Bosses = require("bosses")
local UI = require("ui")

local estado = "menu"
local pontos = 0
local tempoPartida = 0

local jogador
local inimigos
local chefes
local interface

local coracao = nil
local timerSpawnCoracao = 30

local powerup = nil
local timerSpawnPowerup = 35
local timerTiroRapidoAtivo = 0
local timerEscudoAtivo = 0
local tiposPowerup = {}
local musicaPausada = nil
local cena2Ativa = false
local transicaoCenario = nil

local function colisaoCirculo(x1, y1, raio1, x2, y2, raio2)
    local dx = x1 - x2
    local dy = y1 - y2

    return dx * dx + dy * dy < (raio1 + raio2) * (raio1 + raio2)
end

local function reiniciarJogo()
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()
    cena2Ativa = false
    transicaoCenario = nil

    estado = "jogando"
    pontos = 0
    tempoPartida = 0

    Player.reset(jogador, larguraTela, alturaTela)
    Enemies.reset(inimigos)
    Bosses.reset(chefes, Assets.audio)

    coracao = nil
    timerSpawnCoracao = 30

    powerup = nil
    timerSpawnPowerup = 35
    timerTiroRapidoAtivo = 0
    timerEscudoAtivo = 0
end

local function atualizarItens(dt, larguraTela, alturaTela)
    timerSpawnCoracao = timerSpawnCoracao - dt

    if timerSpawnCoracao <= 0 then
        timerSpawnCoracao = 30

        coracao = {
            x = love.math.random(80, larguraTela - 80),
            y = love.math.random(80, alturaTela - 80),
            tamanho = 36,
            tempoRestante = 5
        }
    end

    if coracao then
        coracao.tempoRestante = coracao.tempoRestante - dt

        if coracao.tempoRestante <= 0 then
            coracao = nil
        elseif colisaoCirculo(
            jogador.x,
            jogador.y,
            jogador.tamanho / 2.2,
            coracao.x,
            coracao.y,
            coracao.tamanho / 2
        ) then
            if jogador.vidas < 3 then
                jogador.vidas = jogador.vidas + 1
            else
                pontos = pontos + 50
            end

            coracao = nil
        end
    end

    timerSpawnPowerup = timerSpawnPowerup - dt

    if timerSpawnPowerup <= 0 then
        timerSpawnPowerup = 35

        local tipoSorteado = tiposPowerup[
            love.math.random(1, #tiposPowerup)
        ]

        powerup = {
            tipo = tipoSorteado,
            x = love.math.random(80, larguraTela - 80),
            y = love.math.random(80, alturaTela - 80),
            tamanho = tipoSorteado.tamanho,
            tempoRestante = 5
        }
    end

    if powerup then
        powerup.tempoRestante = powerup.tempoRestante - dt

        if powerup.tempoRestante <= 0 then
            powerup = nil
        elseif colisaoCirculo(
            jogador.x,
            jogador.y,
            jogador.tamanho / 2.2,
            powerup.x,
            powerup.y,
            powerup.tamanho / 2
        ) then
            powerup.tipo.aoColetar()
            powerup = nil
        end
    end
end

local function desenharItens()
    if coracao then
        local imagem = Assets.images.coracao
        local escalaBase = coracao.tamanho / imagem:getWidth()
        local pulso = 1 + math.sin(love.timer.getTime() * 8) * 0.12
        local escala = escalaBase * pulso

        if coracao.tempoRestante <= 1.5
        and math.floor(coracao.tempoRestante * 8) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.25)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.draw(
            imagem,
            coracao.x,
            coracao.y,
            0,
            escala,
            escala,
            imagem:getWidth() / 2,
            imagem:getHeight() / 2
        )
    end

    if powerup then
        local imagem = powerup.tipo.imagem
        local pulso = 1 + math.sin(love.timer.getTime() * 8) * 0.12
        local escala = powerup.tipo.escala * pulso

        if powerup.tempoRestante <= 1.5
        and math.floor(powerup.tempoRestante * 8) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.25)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.draw(
            imagem,
            powerup.x,
            powerup.y,
            0,
            escala,
            escala,
            imagem:getWidth() / 2,
            imagem:getHeight() / 2
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function love.load()
    Assets.load()

    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()

    jogador = Player.new(Assets, larguraTela, alturaTela)
    inimigos = Enemies.new()
    chefes = Bosses.new()
    interface = UI.new(larguraTela, alturaTela)

    tiposPowerup = {
        {
            id = "tiro_rapido",
            imagem = Assets.images.powerupTiroRapido,
            tamanho = 36,
            escala = 36 / Assets.images.powerupTiroRapido:getWidth(),
            aoColetar = function()
                timerTiroRapidoAtivo = 10
            end
        },
        {
            id = "escudo",
            imagem = Assets.images.powerupEscudo,
            tamanho = 36,
            escala = 36 / Assets.images.powerupEscudo:getWidth(),
            aoColetar = function()
                timerEscudoAtivo = 10
            end
        }
    }

    Assets.audio.musicaFundo:play()
end

local function pausarJogo()
    estado = "pausado"

    musicaPausada = nil

    if Assets.audio.musicaBatalha:isPlaying() then
        musicaPausada = "batalha"
        Assets.audio.musicaBatalha:pause()
    elseif Assets.audio.musicaFundo:isPlaying() then
        musicaPausada = "fundo"
        Assets.audio.musicaFundo:pause()
    end
end

local function voltarAoJogo()
    estado = "jogando"

    if musicaPausada == "batalha" then
        Assets.audio.musicaBatalha:play()
    elseif musicaPausada == "fundo" then
        Assets.audio.musicaFundo:play()
    end

    musicaPausada = nil
end

local function voltarAoMenuPrincipal()
    estado = "menu"

    if Assets.audio.musicaBatalha:isPlaying() then
        Assets.audio.musicaBatalha:stop()
    end

    Assets.audio.musicaFundo:play()
    musicaPausada = nil
end

local function iniciarTransicaoCenario()
    transicaoCenario = {
        tempo = 0,
        duracao = 2.5
    }
end

function love.update(dt)
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()

    UI.update(interface, dt, larguraTela, estado)

    if estado ~= "jogando" then
        return
    end

    if transicaoCenario then
        transicaoCenario.tempo = transicaoCenario.tempo + dt

        if transicaoCenario.tempo >= transicaoCenario.duracao then
            transicaoCenario = nil
            cena2Ativa = true
        end
    end

    tempoPartida = tempoPartida + dt

    timerTiroRapidoAtivo = math.max(0, timerTiroRapidoAtivo - dt)
    timerEscudoAtivo = math.max(0, timerEscudoAtivo - dt)

    Player.update(
        jogador,
        dt,
        larguraTela,
        alturaTela,
        timerTiroRapidoAtivo > 0
    )

    Bosses.update(
        chefes,
        dt,
        jogador,
        tempoPartida,
        larguraTela,
        alturaTela,
        Assets.audio,
        timerEscudoAtivo > 0
    )

    pontos = pontos + Enemies.update(
        inimigos,
        dt,
        jogador,
        tempoPartida,
        larguraTela,
        alturaTela,
        Bosses.isActive(chefes),
        chefes.boss1Derrotado,
        timerEscudoAtivo > 0
    )

    local primeiroBossJaDerrotado = chefes.boss1Derrotado

    pontos = pontos + Bosses.handlePlayerBullets(
        chefes,
        jogador,
        Assets.audio
    )

    if not primeiroBossJaDerrotado and chefes.boss1Derrotado then
        iniciarTransicaoCenario()
    end

    pontos = pontos + Enemies.handlePlayerBullets(inimigos, jogador)

    atualizarItens(dt, larguraTela, alturaTela)

    if jogador.vidas <= 0 then
        estado = "gameover"
    end
end

function love.draw()
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()

    UI.drawBackground(
    Assets,
    larguraTela,
    alturaTela,
    cena2Ativa,
    transicaoCenario
)

    if estado == "menu" then
        UI.drawMenu(interface, Assets, larguraTela, alturaTela)

   elseif estado == "jogando" or estado == "pausado" or estado == "configuracoes" then
        Enemies.draw(inimigos, Assets)
        Bosses.draw(chefes, Assets)
        desenharItens()

        Player.draw(
            jogador,
            Assets,
            timerTiroRapidoAtivo,
            timerEscudoAtivo
        )

        UI.drawHUD({
            player = jogador,
            bosses = chefes,
            pontos = pontos,
            tempoPartida = tempoPartida,
            timerTiroRapido = timerTiroRapidoAtivo,
            timerEscudo = timerEscudoAtivo
        }, Assets, larguraTela, alturaTela)

            if estado == "pausado" then
            UI.drawPauseMenu(
                interface,
                larguraTela,
                alturaTela
            )
        elseif estado == "configuracoes" then
            UI.drawSettingsMenu(
                interface,
                larguraTela,
                alturaTela
            )
        end

    elseif estado == "gameover" then
        UI.drawGameOver(
            pontos,
            tempoPartida,
            larguraTela,
            alturaTela
        )
    end
end

function love.mousepressed(x, y, botao)
    if botao ~= 1 then
        return
    end

    if estado == "menu" then
        if UI.isStartButtonClicked(interface, x, y) then
            reiniciarJogo()
        end

    elseif estado == "pausado" then
        local acao = UI.pauseAction(interface, x, y)

        if acao == "voltar" then
            voltarAoJogo()
        elseif acao == "menu" then
            voltarAoMenuPrincipal()
        elseif acao == "configuracoes" then
            estado = "configuracoes"
        elseif acao == "fechar" then
            love.event.quit()
        end

    elseif estado == "configuracoes" then
        if UI.settingsAction(interface, x, y) == "voltar" then
            estado = "pausado"
        end
    end
end

function love.keypressed(tecla)
    if tecla == "escape" then
        if estado == "jogando" then
            pausarJogo()
        elseif estado == "pausado" then
            voltarAoJogo()
        elseif estado == "configuracoes" then
            estado = "pausado"
        elseif estado == "gameover" then
            voltarAoMenuPrincipal()
        end

    elseif tecla == "r" and estado == "gameover" then
        reiniciarJogo()
    end
end