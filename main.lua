if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local Assets = require("assets")
local Player = require("player")
local Enemies = require("enemies")
local Bosses = require("bosses")
local SecretBoss = require("secret_boss")
local UI = require("ui")

local estado = "menu"
local pontos = 0
local tempoPartida = 0

local jogador
local inimigos
local chefes
local chefeSecreto
local interface

local coracao = nil
local timerSpawnCoracao = 30

local powerup = nil
local timerSpawnPowerup = 35
local timerTiroRapidoAtivo = 0
local timerEscudoAtivo = 0
local tiposPowerup = {}
local musicaPausada = nil
local cenarioAtual = "fundo"
local transicaoCenario = nil
local portal = nil
local timerPortal = 60
local itemDuelo = nil
local timerItemDuelo = 5
local chefeSecretoDerrotado = false
local menuDebugAberto = false
local volumeSom = 0.5
local resolucaoAtual = 1
local origemConfiguracoes = "menu"
local aplicarVolume

local function pararMusicasDeJogo(manter)
    for _, nome in ipairs({ "musicaFundo", "musicaBatalha", "musicaBoss2" }) do
        local musica = Assets.audio[nome]
        if musica and nome ~= manter then
            musica:stop()
        end
    end
end

local function tocarMusicaMenu()
    pararMusicasDeJogo()

    local musicaMenu = Assets.audio.musicaMenu
    musicaMenu:stop()
    musicaMenu:play()
end

local function colisaoCirculo(x1, y1, raio1, x2, y2, raio2)
    local dx = x1 - x2
    local dy = y1 - y2

    return dx * dx + dy * dy < (raio1 + raio2) * (raio1 + raio2)
end

local function reiniciarJogo()
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()
    Assets.audio.musicaMenu:stop()
    cenarioAtual = "fundo"
    transicaoCenario = nil
    portal = nil
    timerPortal = 60
    itemDuelo = nil
    timerItemDuelo = 5
    chefeSecretoDerrotado = false
    menuDebugAberto = false
    SecretBoss.reset(chefeSecreto)

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
    if SecretBoss.isActive(chefeSecreto) then return end

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
    local function drawItem(imagem,x,y,tamanho,alpha)
        local escala=tamanho/imagem:getWidth()
        love.graphics.setColor(1,1,1,alpha or 1)
        love.graphics.draw(imagem,x,y,0,escala,escala,
            imagem:getWidth()/2,imagem:getHeight()/2)
    end
    if coracao then
        local pulso=1+math.sin(love.timer.getTime()*8)*0.12
        local alpha=coracao.tempoRestante<=1.5
            and math.floor(coracao.tempoRestante*8)%2==0 and 0.25 or 1
        drawItem(Assets.images.coracao,coracao.x,coracao.y,
            coracao.tamanho*pulso,alpha)
    end
    if powerup then
        local pulso=1+math.sin(love.timer.getTime()*8)*0.12
        local alpha=powerup.tempoRestante<=1.5
            and math.floor(powerup.tempoRestante*8)%2==0 and 0.25 or 1
        drawItem(powerup.tipo.imagem,powerup.x,powerup.y,
            powerup.tamanho*pulso,alpha)
    end
    if portal then
        local pulso=1+math.sin(love.timer.getTime()*6)*0.1
        drawItem(Assets.images.portal,portal.x,portal.y,portal.tamanho*pulso)
    end
    if itemDuelo then
        local imagens={vida=Assets.images.coracao,
            tiro_rapido=Assets.images.powerupTiroRapido,
            escudo=Assets.images.powerupEscudo}
        drawItem(imagens[itemDuelo.tipo],itemDuelo.x,itemDuelo.y,itemDuelo.tamanho)
    end
    love.graphics.setColor(1,1,1,1)
end

function love.load()
    Assets.load()

    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()

    jogador = Player.new(Assets, larguraTela, alturaTela)
    inimigos = Enemies.new()
    chefes = Bosses.new()
    chefeSecreto = SecretBoss.new()
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

    aplicarVolume()
    tocarMusicaMenu()
end

aplicarVolume = function()
    Assets.audio.musicaFundo:setVolume(volumeSom)
    Assets.audio.musicaMenu:setVolume(volumeSom)
    Assets.audio.musicaBatalha:setVolume(volumeSom)
    Assets.audio.musicaBoss2:setVolume(volumeSom)
end

local function abrirConfiguracoes(origem)
    origemConfiguracoes = origem
    estado = "configuracoes"
end

local function voltarDasConfiguracoes()
    estado = origemConfiguracoes
    interface.ajustandoVolume = false
end

local function alterarResolucao(indice)
    local resolucao = interface.botoesResolucao[indice].resolucao
    local sucesso, mensagem = love.window.setMode(
        resolucao.largura,
        resolucao.altura
    )

    if not sucesso then
        error("Não foi possível alterar a resolução: " .. tostring(mensagem))
    end

    resolucaoAtual = indice
    UI.resize(
        interface,
        love.graphics.getWidth(),
        love.graphics.getHeight()
    )
end

local function pausarJogo()
    estado = "pausado"

    musicaPausada = nil

    if Assets.audio.musicaBoss2:isPlaying() then
        musicaPausada = "boss2"
    elseif Assets.audio.musicaBatalha:isPlaying() then
        musicaPausada = "batalha"
    elseif Assets.audio.musicaFundo:isPlaying() then
        musicaPausada = "fundo"
    end

    local musicas = {
        fundo = Assets.audio.musicaFundo,
        batalha = Assets.audio.musicaBatalha,
        boss2 = Assets.audio.musicaBoss2
    }

    for nome, musica in pairs(musicas) do
        if nome == musicaPausada then
            musica:pause()
        else
            musica:stop()
        end
    end
end

local function voltarAoJogo()
    estado = "jogando"

    local nomesMusica = {
        fundo = "musicaFundo",
        batalha = "musicaBatalha",
        boss2 = "musicaBoss2"
    }
    local musicaRetomar = nomesMusica[musicaPausada]
    pararMusicasDeJogo(musicaRetomar)

    if musicaRetomar then
        Assets.audio[musicaRetomar]:play()
    end

    musicaPausada = nil
end

local function voltarAoMenuPrincipal()
    estado = "menu"
    tocarMusicaMenu()
    musicaPausada = nil
end

local function iniciarTransicaoCenario(destino)
    transicaoCenario={tempo=0,duracao=2.5,origem=cenarioAtual,destino=destino}
end

local function resetarCombateParaDebug()
    Bosses.reset(chefes, Assets.audio)
    SecretBoss.reset(chefeSecreto)
    portal = nil
    itemDuelo = nil
    coracao = nil
    powerup = nil
    timerPortal = 60
    timerItemDuelo = 5
    chefeSecretoDerrotado = false
    transicaoCenario = nil
end

local function executarAcaoDebug(acao)
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()

    if acao == "boss1" then
        resetarCombateParaDebug()
        cenarioAtual = "fundo"
        Bosses.debugSpawn(chefes, 1, larguraTela, Assets.audio)

    elseif acao == "boss2" then
        resetarCombateParaDebug()
        cenarioAtual = "cena2"
        Bosses.debugSpawn(chefes, 2, larguraTela, Assets.audio)

    elseif acao == "portal" then
        resetarCombateParaDebug()
        cenarioAtual = "cena2"
        chefes.boss1JaApareceu = true
        chefes.boss1Derrotado = true
        chefes.boss2JaApareceu = true
        chefes.boss2Derrotado = true
        portal = {
            x = love.math.random(80, larguraTela - 80),
            y = love.math.random(80, alturaTela - 80),
            tamanho = 56,
            tempoRestante = 5
        }

    elseif acao == "secreto" then
        resetarCombateParaDebug()
        Enemies.reset(inimigos)
        timerItemDuelo = 5
        chefes.boss1JaApareceu = true
        chefes.boss1Derrotado = true
        chefes.boss2JaApareceu = true
        chefes.boss2Derrotado = true
        SecretBoss.start(
            chefeSecreto,
            jogador,
            larguraTela,
            alturaTela,
            Assets.audio
        )
        cenarioAtual = "cena2"
        iniciarTransicaoCenario("cenaEspecial")

    elseif acao == "tempo" then
        if chefes.boss1Derrotado and not chefes.boss2JaApareceu then
            chefes.timerSpawnBoss2 = 0
        else
            tempoPartida = tempoPartida + 30
        end

    elseif acao == "cura" then
        jogador.vidas = 3
        jogador.tempoInvulneravel = 0
    end
end

local function atualizarPortal(dt,w,h)
    if not chefes.boss2Derrotado or chefeSecretoDerrotado
    or SecretBoss.isActive(chefeSecreto) then return end
    if portal then
        portal.tempoRestante=portal.tempoRestante-dt
        if portal.tempoRestante<=0 then
            portal=nil
        elseif colisaoCirculo(jogador.x,jogador.y,jogador.tamanho/2.2,
            portal.x,portal.y,portal.tamanho/2) then
            portal=nil
            coracao=nil
            powerup=nil
            itemDuelo=nil
            timerItemDuelo=5
            Enemies.reset(inimigos)
            SecretBoss.start(chefeSecreto,jogador,w,h,Assets.audio)
            iniciarTransicaoCenario("cenaEspecial")
        end
        return
    end
    timerPortal=timerPortal-dt
    if timerPortal<=0 then
        portal={x=love.math.random(80,w-80),y=love.math.random(80,h-80),
            tamanho=56,tempoRestante=5}
        timerPortal=60
    end
end

local function atualizarItemDuelo(dt,w,h)
    if not SecretBoss.isActive(chefeSecreto) then
        itemDuelo=nil
        return
    end

    timerItemDuelo=timerItemDuelo-dt

    if itemDuelo then
        itemDuelo.tempoRestante=itemDuelo.tempoRestante-dt
        if itemDuelo.tempoRestante<=0 then
            itemDuelo=nil
        end
    end

    if not itemDuelo and timerItemDuelo<=0 then
        local tipos={"vida","tiro_rapido","escudo"}
        itemDuelo={tipo=tipos[love.math.random(1,#tipos)],
            x=love.math.random(70,w-70),y=love.math.random(70,h-70),
            tamanho=36,tempoRestante=5}
        timerItemDuelo=5
    end

    if not itemDuelo then return end

    if colisaoCirculo(jogador.x,jogador.y,jogador.tamanho/2.2,
        itemDuelo.x,itemDuelo.y,itemDuelo.tamanho/2) then
        if itemDuelo.tipo=="vida" then
            jogador.vidas=math.min(3,jogador.vidas+1)
        elseif itemDuelo.tipo=="tiro_rapido" then
            timerTiroRapidoAtivo=10
        else
            timerEscudoAtivo=10
        end
        itemDuelo=nil
        return
    end
    local boss=chefeSecreto.boss
    if boss and colisaoCirculo(boss.x,boss.y,boss.tamanho/2.2,
        itemDuelo.x,itemDuelo.y,itemDuelo.tamanho/2) then
        SecretBoss.collectItem(chefeSecreto,itemDuelo.tipo)
        itemDuelo=nil
    end
end

function love.update(dt)
    local w=love.graphics.getWidth()
    local h=love.graphics.getHeight()
    UI.update(interface,dt,w,estado)
    if estado~="jogando" then return end
    if menuDebugAberto then return end

    if transicaoCenario then
        transicaoCenario.tempo=transicaoCenario.tempo+dt
        if transicaoCenario.tempo>=transicaoCenario.duracao then
            cenarioAtual=transicaoCenario.destino
            transicaoCenario=nil
        end
    end
    tempoPartida=tempoPartida+dt
    timerTiroRapidoAtivo=math.max(0,timerTiroRapidoAtivo-dt)
    timerEscudoAtivo=math.max(0,timerEscudoAtivo-dt)
    Player.update(jogador,dt,w,h,timerTiroRapidoAtivo>0)
    Bosses.update(chefes,dt,jogador,tempoPartida,w,h,
        Assets.audio,timerEscudoAtivo>0)
    atualizarPortal(dt,w,h)

    local dueloSecretoAtivo=SecretBoss.isActive(chefeSecreto)
    pontos=pontos+Enemies.update(inimigos,dt,jogador,tempoPartida,w,h,
        Bosses.isActive(chefes) or dueloSecretoAtivo,
        chefes.boss1Derrotado,timerEscudoAtivo>0)
    atualizarItens(dt,w,h)

    if dueloSecretoAtivo then
        SecretBoss.update(chefeSecreto,dt,jogador,w,h,
            timerEscudoAtivo>0,itemDuelo)
        atualizarItemDuelo(dt,w,h)
        if SecretBoss.handlePlayerBullets(chefeSecreto,jogador,Assets.audio) then
            itemDuelo=nil
            chefeSecretoDerrotado=true
            iniciarTransicaoCenario("cena2")
        end
    else
        local boss1Antes=chefes.boss1Derrotado
        pontos=pontos+Bosses.handlePlayerBullets(chefes,jogador,Assets.audio)
        if not boss1Antes and chefes.boss1Derrotado then
            iniciarTransicaoCenario("cena2")
        end
    end
    if not dueloSecretoAtivo then
        pontos=pontos+Enemies.handlePlayerBullets(inimigos,jogador)
    end
    if jogador.vidas<=0 then
        estado="gameover"
        pararMusicasDeJogo()
    end
end

function love.draw()
    local w=love.graphics.getWidth()
    local h=love.graphics.getHeight()
    UI.drawBackground(Assets,w,h,cenarioAtual,transicaoCenario)
    if estado=="menu" then
        UI.drawMenu(interface,Assets,w,h)
    elseif estado=="instrucoes" then
        UI.drawInstructions(interface,w,h)
    elseif estado=="configuracoes" and origemConfiguracoes=="menu" then
        UI.drawSettingsMenu(interface,w,h,volumeSom,resolucaoAtual)
    elseif estado=="jogando" or estado=="pausado" or estado=="configuracoes" then
        Enemies.draw(inimigos,Assets)
        Bosses.draw(chefes,Assets)
        SecretBoss.draw(chefeSecreto,Assets)
        desenharItens()
        Player.draw(jogador,Assets,timerTiroRapidoAtivo,timerEscudoAtivo)
        local chefeParaHUD=SecretBoss.isActive(chefeSecreto)
            and chefeSecreto or chefes
        UI.drawHUD({
            player=jogador,bosses=chefeParaHUD,pontos=pontos,
            tempoPartida=tempoPartida,timerTiroRapido=timerTiroRapidoAtivo,
            timerEscudo=timerEscudoAtivo
        },Assets,w,h)
        if estado=="pausado" then
            UI.drawPauseMenu(interface,w,h)
        elseif estado=="configuracoes" then
            UI.drawSettingsMenu(interface,w,h,volumeSom,resolucaoAtual)
        end

        if menuDebugAberto then
            UI.drawDebugMenu(interface,w,h)
        end
    elseif estado=="gameover" then
        UI.drawGameOver(pontos,tempoPartida,w,h)
    end
end

function love.mousepressed(x, y, botao)
    if botao ~= 1 then
        return
    end

    if menuDebugAberto then
        local acao = UI.debugAction(interface, x, y)
        if acao then
            executarAcaoDebug(acao)
            menuDebugAberto = false
        end
        return
    end

    if estado == "menu" then
        if UI.isStartButtonClicked(interface, x, y) then
            reiniciarJogo()
        elseif UI.isInstructionsButtonClicked(interface, x, y) then
            estado = "instrucoes"
        elseif UI.isMenuSettingsButtonClicked(interface, x, y) then
            abrirConfiguracoes("menu")
        elseif UI.isExitButtonClicked(interface, x, y) then
            love.event.quit()
        end

    elseif estado == "instrucoes" then
        if UI.isInstructionsBackClicked(interface, x, y) then
            estado = "menu"
        end

    elseif estado == "pausado" then
        local acao = UI.pauseAction(interface, x, y)

        if acao == "voltar" then
            voltarAoJogo()
        elseif acao == "menu" then
            voltarAoMenuPrincipal()
        elseif acao == "configuracoes" then
            abrirConfiguracoes("pausado")
        elseif acao == "fechar" then
            love.event.quit()
        end

    elseif estado == "configuracoes" then
        local acao, valor = UI.settingsAction(interface, x, y)

        if acao == "voltar" then
            voltarDasConfiguracoes()
        elseif acao == "volume" then
            volumeSom = valor
            aplicarVolume()
        elseif acao == "resolucao" then
            alterarResolucao(valor)
        end
    end
end

function love.mousemoved(x)
    if estado == "configuracoes" and interface.ajustandoVolume then
        volumeSom = UI.volumeAt(interface, x)
        aplicarVolume()
    end
end

function love.mousereleased(_, _, botao)
    if botao == 1 then
        interface.ajustandoVolume = false
    end
end

function love.resize(largura, altura)
    if interface then
        UI.resize(interface, largura, altura)
    end
end

function love.keypressed(tecla)
    if menuDebugAberto then
        if tecla == "h" or tecla == "escape" then
            menuDebugAberto = false
        end
        return
    end

    if tecla == "h" and estado == "jogando" then
        menuDebugAberto = true
        return
    end

    if tecla == "escape" then
        if estado == "jogando" then
            pausarJogo()
        elseif estado == "pausado" then
            voltarAoJogo()
        elseif estado == "configuracoes" then
            voltarDasConfiguracoes()
        elseif estado == "instrucoes" then
            estado = "menu"
        elseif estado == "gameover" then
            voltarAoMenuPrincipal()
        end
    elseif tecla == "r" and estado == "gameover" then
        reiniciarJogo()
    end
end
