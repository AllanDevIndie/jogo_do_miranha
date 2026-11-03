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
local resultadoFinal = "vitoria"
local tempoCreditos = 0

local jogador
local inimigos
local chefes
local chefeSecreto
local interface

local coracao = nil
-- Intervalo de surgimento dos corações; ajuste tempoRestante abaixo para sua duração.
local timerSpawnCoracao = 30

local powerups = {}
-- Power-ups básicos: intervalo de surgimento; cada item fica 5 segundos na tela.
local timerSpawnPowerup = 35
local timerTiroRapidoAtivo = 0
local timerEscudoAtivo = 0
local powerupsNovosLiberados = false
local timerPowerupTeleguiado = nil
local timerPowerupTiroPotente = nil
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
    for _, nome in ipairs({
        "musicaFundo",
        "musicaBatalha",
        "musicaBoss2",
        "musicaCreditos",
        "musicaGameOver"
    }) do
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

local function iniciarCreditos(resultado)
    pararMusicasDeJogo()
    resultadoFinal = resultado
    tempoCreditos = 0
    estado = "creditos"
    Assets.audio.musicaCreditos:stop()
    Assets.audio.musicaCreditos:play()
end

local function iniciarGameOver()
    pararMusicasDeJogo()
    estado = "gameover"
    Assets.audio.musicaGameOver:stop()
    Assets.audio.musicaGameOver:play()
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
    Assets.audio.musicaCreditos:stop()
    Assets.audio.musicaGameOver:stop()
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

    powerups = {}
    timerSpawnPowerup = 35
    timerTiroRapidoAtivo = 0
    timerEscudoAtivo = 0
    powerupsNovosLiberados = false
    timerPowerupTeleguiado = nil
    timerPowerupTiroPotente = nil
end

local function criarPowerup(tipo, larguraTela, alturaTela, x, y)
    table.insert(powerups, {
        tipo = tipo,
        x = x or love.math.random(80, larguraTela - 80),
        y = y or love.math.random(80, alturaTela - 80),
        tamanho = tipo.tamanho,
        -- Tempo que um power-up permanece disponível antes de desaparecer.
        tempoRestante = 5
    })
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
            -- Tempo que o coração permanece disponível.
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

        criarPowerup(
            tiposPowerup[love.math.random(1, 2)],
            larguraTela,
            alturaTela
        )
    end

    if chefes.boss2Derrotado and not powerupsNovosLiberados then
        powerupsNovosLiberados = true
        -- Novos poderes: primeiro atraso e fase do segundo tipo (15 s depois).
        timerPowerupTeleguiado = 15
        timerPowerupTiroPotente = 30
    end

    if powerupsNovosLiberados then
        timerPowerupTeleguiado = timerPowerupTeleguiado - dt
        timerPowerupTiroPotente = timerPowerupTiroPotente - dt

        if timerPowerupTeleguiado <= 0 then
            criarPowerup(tiposPowerup[3], larguraTela, alturaTela)
            timerPowerupTeleguiado = 35
        end
        if timerPowerupTiroPotente <= 0 then
            criarPowerup(tiposPowerup[4], larguraTela, alturaTela)
            timerPowerupTiroPotente = 35
        end
    end

    for indice = #powerups, 1, -1 do
        local powerup = powerups[indice]
        powerup.tempoRestante = powerup.tempoRestante - dt

        if powerup.tempoRestante <= 0 then
            table.remove(powerups, indice)
        elseif colisaoCirculo(
            jogador.x,
            jogador.y,
            jogador.tamanho / 2.2,
            powerup.x,
            powerup.y,
            powerup.tamanho / 2
        ) then
            powerup.tipo.aoColetar()
            table.remove(powerups, indice)
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
    for _, powerup in ipairs(powerups) do
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
            -- Tamanho do item e duração do efeito do tiro rápido.
            tamanho = 36,
            escala = 36 / Assets.images.powerupTiroRapido:getWidth(),
            aoColetar = function()
                -- Duração do efeito de tiro rápido.
                timerTiroRapidoAtivo = 10
            end
        },
        {
            id = "escudo",
            imagem = Assets.images.powerupEscudo,
            -- Tamanho do item e duração do escudo.
            tamanho = 36,
            escala = 36 / Assets.images.powerupEscudo:getWidth(),
            aoColetar = function()
                -- Duração do efeito de escudo.
                timerEscudoAtivo = 10
            end
        },
        {
            id = "teleguiado",
            imagem = Assets.images.powerupTeleguiado,
            -- Tamanho de exibição do item teleguiado.
            tamanho = 42,
            aoColetar = function()
                Enemies.activateGuidedPower(inimigos)
            end
        },
        {
            id = "tiro_potente",
            imagem = Assets.images.powerupTiroPotente,
            -- Tamanho de exibição do item; o dano/tamanho do tiro fica em player.lua.
            tamanho = 42,
            aoColetar = function()
                jogador.tiroPotenteAtivo = true
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
    Assets.audio.musicaCreditos:setVolume(volumeSom)
    Assets.audio.musicaGameOver:setVolume(volumeSom)
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
    powerups = {}
    timerPortal = 60
    timerItemDuelo = 5
    chefeSecretoDerrotado = false
    transicaoCenario = nil
    powerupsNovosLiberados = false
    timerPowerupTeleguiado = nil
    timerPowerupTiroPotente = nil
end

local function executarAcaoDebug(acao)
    local larguraTela = love.graphics.getWidth()
    local alturaTela = love.graphics.getHeight()
    local tiposBoss = {
        boss1 = 1,
        boss2 = 2,
        boss3 = 3,
        boss4 = 4,
        bossFinal = 5
    }
    local tipoBoss = tiposBoss[acao]

    if tipoBoss then
        resetarCombateParaDebug()
        cenarioAtual = tipoBoss == 1 and "fundo"
            or tipoBoss == 2 and "cena2"
            or tipoBoss == 3 and "cena3"
            or "cena4"
        Bosses.debugSpawn(chefes, tipoBoss, larguraTela, Assets.audio)

    elseif acao == "inimigo1" or acao == "inimigo2"
    or acao == "inimigo3" or acao == "inimigo4" then
        local tipoInimigo = tonumber(string.sub(acao, -1))
        Enemies.debugSpawn(inimigos, tipoInimigo, larguraTela, alturaTela)

    elseif acao == "tiroRapido" then
        timerTiroRapidoAtivo = 10

    elseif acao == "escudo" then
        timerEscudoAtivo = 10

    elseif acao == "teleguiado" then
        Enemies.activateGuidedPower(inimigos)

    elseif acao == "tiroPotente" then
        jogador.tiroPotenteAtivo = true

    elseif acao == "creditos" then
        iniciarCreditos("vitoria")

    elseif acao == "portal" then
        resetarCombateParaDebug()
        cenarioAtual = "cena3"
        chefes.boss1JaApareceu = true
        chefes.boss1Derrotado = true
        chefes.boss2JaApareceu = true
        chefes.boss2Derrotado = true
        chefes.bossesDerrotados = 2
        chefes.timerSpawnBoss2 = 25
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
        chefes.bossesDerrotados = 2
        chefes.timerSpawnBoss2 = 25
        SecretBoss.start(
            chefeSecreto,
            jogador,
            larguraTela,
            alturaTela,
            Assets.audio
        )
        cenarioAtual = "cena3"
        iniciarTransicaoCenario("cenaEspecial")

    elseif acao == "tempo" then
        if chefes.bossesDerrotados > 0 and chefes.bossesDerrotados < 5
        and not Bosses.isActive(chefes) then
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
    or SecretBoss.isActive(chefeSecreto)
    or Bosses.isActive(chefes) then return end
    if portal then
        portal.tempoRestante=portal.tempoRestante-dt
        if portal.tempoRestante<=0 then
            portal=nil
        elseif colisaoCirculo(jogador.x,jogador.y,jogador.tamanho/2.2,
            portal.x,portal.y,portal.tamanho/2) then
            portal=nil
            coracao=nil
            powerups={}
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
    if boss and boss.visivel
    and (boss.fase=="ataque" or boss.fase=="pausa")
    and colisaoCirculo(boss.x,boss.y,boss.tamanho/2.2,
        itemDuelo.x,itemDuelo.y,itemDuelo.tamanho/2) then
        SecretBoss.collectItem(chefeSecreto,itemDuelo.tipo)
        itemDuelo=nil
    end
end

local function atualizarMisseisTeleguiados(dt,w,h,dueloSecretoAtivo)
    local alvosBoss = {}

    if dueloSecretoAtivo then
        local boss = chefeSecreto.boss
        if boss.visivel
        and (boss.fase == "ataque" or boss.fase == "pausa")
        and boss.timerEscudo <= 0 then
            table.insert(alvosBoss, boss)
        end
    elseif chefes.boss and not chefes.bossEntrando then
        local boss = chefes.boss
        local vulneravel = (boss.tipo ~= 2 and boss.tipo ~= 4)
            or boss.timerVulneravel > 0
        if vulneravel then
            table.insert(alvosBoss, boss)
        end
    end

    pontos = pontos + Enemies.updateGuidedMissiles(
        inimigos,
        dt,
        jogador,
        w,
        h,
        Bosses.isActive(chefes) or dueloSecretoAtivo,
        alvosBoss
    )
end

function love.update(dt)
    local w=love.graphics.getWidth()
    local h=love.graphics.getHeight()
    UI.update(interface,dt,w,estado)
    if estado=="creditos" then
        tempoCreditos = tempoCreditos + dt
        return
    end
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
    local vidasAntes = jogador.vidas
    local dueloSecretoAtivo=SecretBoss.isActive(chefeSecreto)
    Player.update(jogador,dt,w,h,timerTiroRapidoAtivo>0)
    Bosses.update(chefes,dt,jogador,tempoPartida,w,h,
        Assets.audio,timerEscudoAtivo>0,dueloSecretoAtivo)
    atualizarPortal(dt,w,h)

    pontos=pontos+Enemies.update(inimigos,dt,jogador,tempoPartida,w,h,
        Bosses.isActive(chefes) or dueloSecretoAtivo,
        chefes.boss1Derrotado,timerEscudoAtivo>0,
        chefes.bossesDerrotados)
    if jogador.vidas < vidasAntes then
        jogador.tiroPotenteAtivo = false
    end
    atualizarItens(dt,w,h)

    if dueloSecretoAtivo then
        SecretBoss.update(chefeSecreto,dt,jogador,w,h,
            timerEscudoAtivo>0,itemDuelo)
        atualizarItemDuelo(dt,w,h)
        atualizarMisseisTeleguiados(dt,w,h,dueloSecretoAtivo)
        if SecretBoss.handlePlayerBullets(chefeSecreto,jogador,Assets.audio) then
            itemDuelo=nil
            chefeSecretoDerrotado=true
            local cenaRetorno = chefes.bossesDerrotados >= 3
                and "cena4" or "cena3"
            iniciarTransicaoCenario(cenaRetorno)
        end
    else
        atualizarMisseisTeleguiados(dt,w,h,false)
        local chefesDerrotadosAntes = chefes.bossesDerrotados
        pontos=pontos+Bosses.handlePlayerBullets(chefes,jogador,Assets.audio)
        if chefes.bossesDerrotados > chefesDerrotadosAntes then
            local cenasProximoEstagio = {
                [1] = "cena2",
                [2] = "cena3",
                [3] = "cena4",
                [4] = "cena4"
            }
            if chefes.bossesDerrotados == 5 then
                resultadoFinal = "vitoria"
            else
                iniciarTransicaoCenario(
                    cenasProximoEstagio[chefes.bossesDerrotados]
                )
            end
        end
    end
    if not dueloSecretoAtivo then
        pontos=pontos+Enemies.handlePlayerBullets(inimigos,jogador)
    end
    if jogador.vidas<=0 then
        iniciarGameOver()
    elseif resultadoFinal=="vitoria" and chefes.bossesDerrotados==5
    and not dueloSecretoAtivo then
        iniciarCreditos("vitoria")
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
            timerEscudo=timerEscudoAtivo,
            timerTeleguiado=inimigos.timerPoderTeleguiado,
            tiroPotente=jogador.tiroPotenteAtivo
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
        UI.drawGameOver(interface,pontos,tempoPartida,w,h)
    elseif estado=="vitoria" then
        UI.drawVictory(pontos,tempoPartida,w,h)
    elseif estado=="creditos" then
        UI.drawCredits(tempoCreditos,resultadoFinal,w,h)
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
        elseif estado == "vitoria" then
            voltarAoMenuPrincipal()
        elseif estado == "gameover" then
            voltarAoMenuPrincipal()
        elseif estado == "creditos" then
            voltarAoMenuPrincipal()
        end
    elseif (tecla == "return" or tecla == "kpenter")
    and estado == "creditos" and tempoCreditos >= 18 then
        voltarAoMenuPrincipal()
    elseif tecla == "r"
    and (estado == "gameover" or estado == "vitoria" or estado == "creditos") then
        reiniciarJogo()
    end
end
