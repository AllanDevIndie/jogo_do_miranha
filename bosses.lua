local Bosses = {}

local function colisaoCirculo(x1, y1, raio1, x2, y2, raio2)
    local dx = x1 - x2
    local dy = y1 - y2

    return dx * dx + dy * dy < (raio1 + raio2) * (raio1 + raio2)
end

local function tocarMusicaDeBatalha(audio, tipoBoss)
    if not audio then
        return
    end

    if audio.musicaMenu then
        audio.musicaMenu:stop()
    end

    if audio.musicaFundo and audio.musicaFundo:isPlaying() then
        audio.musicaFundo:pause()
    end

    if audio.musicaBatalha then
        audio.musicaBatalha:stop()
    end

    if audio.musicaBoss2 then
        audio.musicaBoss2:stop()
    end

    local musica = tipoBoss == 2
        and audio.musicaBoss2
        or audio.musicaBatalha

    if musica then
        musica:play()
    end
end

local function voltarMusicaDeFundo(audio)
    if not audio then
        return
    end

    if audio.musicaMenu then
        audio.musicaMenu:stop()
    end

    if audio.musicaBatalha then
        audio.musicaBatalha:stop()
    end

    if audio.musicaBoss2 then
        audio.musicaBoss2:stop()
    end

    if audio.musicaFundo then
        audio.musicaFundo:play()
    end
end

local function moverBossAte(boss, alvoX, alvoY, velocidade, dt)
    local dx = alvoX - boss.x
    local dy = alvoY - boss.y
    local distancia = math.sqrt(dx * dx + dy * dy)

    if distancia <= velocidade * dt or distancia == 0 then
        boss.x = alvoX
        boss.y = alvoY
        return true
    end

    boss.x = boss.x + dx / distancia * velocidade * dt
    boss.y = boss.y + dy / distancia * velocidade * dt
    return false
end

local function escolherAlvoBossFinal(boss, larguraTela, alturaTela)
    local margem = boss.tamanho / 2
    local borda = love.math.random(1, 4)

    while borda == boss.bordaAlvoAnterior do
        borda = love.math.random(1, 4)
    end

    boss.bordaAlvoAnterior = borda
    if borda == 1 then
        boss.alvoX = margem
        boss.alvoY = love.math.random(margem, alturaTela - margem)
    elseif borda == 2 then
        boss.alvoX = larguraTela - margem
        boss.alvoY = love.math.random(margem, alturaTela - margem)
    elseif borda == 3 then
        boss.alvoX = love.math.random(margem, larguraTela - margem)
        boss.alvoY = margem
    else
        boss.alvoX = love.math.random(margem, larguraTela - margem)
        boss.alvoY = alturaTela - margem
    end
end

local function criarBoss(bosses, tipo, larguraTela)
    bosses.bossEntrando = true
    -- Duração do aviso de entrada dos bosses.
    bosses.timerIntro = 4

    -- Ajuste por boss: vida, tamanho, velocidade de movimento e intervalo dos tiros.
    local configuracoes = {
        -- Boss 1
        { nome = "Chefão", tamanho = 96, vida = 30, velocidade = 145, intervalo = 1.8 },
        -- Boss 2
        { nome = "CTHULHU", tamanho = 110, vida = 52, velocidade = 125, intervalo = 4.5 },
        -- Boss 3
        { nome = "BOSS 3", tamanho = 112, vida = 48, velocidade = 155, intervalo = 3.2 },
        -- Boss 4
        { nome = "BOSS 4", tamanho = 120, vida = 60, velocidade = 115, intervalo = 3.8 },
        -- Boss final
        { nome = "CHEFE FINAL", tamanho = 136, vida = 150, velocidade = 240, intervalo = 1.5 }
    }
    local configuracao = configuracoes[tipo]

    bosses.boss = {
        tipo = tipo,
        nome = configuracao.nome,
        x = larguraTela / 2,
        y = -configuracao.tamanho,
        alvoY = 110,
        velocidade = configuracao.velocidade,
        tamanho = configuracao.tamanho,
        vida = configuracao.vida,
        vidaMaxima = configuracao.vida,
        timerTiro = 1,
        intervaloTiro = configuracao.intervalo,
        timerVulneravel = 0,
        timerDash = 5,
        tempoDash = 0,
        direcaoMovimento = 1,
        tempoSemDano = 0,
        timerRegeneracao = 0
    }
end

function Bosses.new()
    return {
        boss = nil,
        bossEntrando = false,
        timerIntro = 0,
        boss1JaApareceu = false,
        boss1Derrotado = false,
        boss2JaApareceu = false,
        boss2Derrotado = false,
        timerSpawnBoss2 = -1,
        bossesDerrotados = 0,
        ultimoDerrotado = nil,
        tirosInimigos = {}
    }
end

function Bosses.reset(bosses, audio)
    bosses.boss = nil
    bosses.bossEntrando = false
    bosses.timerIntro = 0
    bosses.boss1JaApareceu = false
    bosses.boss1Derrotado = false
    bosses.boss2JaApareceu = false
    bosses.boss2Derrotado = false
    bosses.timerSpawnBoss2 = -1
    bosses.bossesDerrotados = 0
    bosses.ultimoDerrotado = nil
    bosses.tirosInimigos = {}

    if audio then
        if audio.musicaMenu then
            audio.musicaMenu:stop()
        end

        if audio.musicaBoss2 then
            audio.musicaBoss2:stop()
        end

        if audio.musicaBatalha then
            audio.musicaBatalha:stop()
        end

        if audio.musicaFundo then
            audio.musicaFundo:stop()
            audio.musicaFundo:play()
        end
    end
end

function Bosses.isActive(bosses)
    return bosses.boss ~= nil
end

function Bosses.debugSpawn(bosses, tipo, larguraTela, audio)
    if tipo < 1 or tipo > 5 then
        error("Tipo de chefe inválido: " .. tostring(tipo))
    end

    bosses.boss = nil
    bosses.bossEntrando = false
    bosses.tirosInimigos = {}
    bosses.timerSpawnBoss2 = -1
    bosses.bossesDerrotados = tipo - 1
    bosses.ultimoDerrotado = nil
    bosses.boss1JaApareceu = tipo >= 1
    bosses.boss1Derrotado = tipo > 1
    bosses.boss2JaApareceu = tipo >= 2
    bosses.boss2Derrotado = tipo > 2

    criarBoss(bosses, tipo, larguraTela)
    tocarMusicaDeBatalha(audio, tipo)
end

function Bosses.update(
    bosses,
    dt,
    player,
    tempoPartida,
    larguraTela,
    alturaTela,
    audio,
    escudoAtivo,
    pausarProgressao
)
    if not pausarProgressao and not bosses.boss then
        if bosses.bossesDerrotados == 0
        and tempoPartida >= 30
        and not bosses.boss1JaApareceu then
            bosses.boss1JaApareceu = true
            criarBoss(bosses, 1, larguraTela)
            tocarMusicaDeBatalha(audio, 1)
        elseif bosses.bossesDerrotados > 0
        and bosses.bossesDerrotados < 5
        and bosses.timerSpawnBoss2 >= 0 then
            bosses.timerSpawnBoss2 = bosses.timerSpawnBoss2 - dt

            if bosses.timerSpawnBoss2 <= 0 then
                local proximoTipo = bosses.bossesDerrotados + 1
                if proximoTipo == 2 then
                    bosses.boss2JaApareceu = true
                end

                criarBoss(bosses, proximoTipo, larguraTela)
                tocarMusicaDeBatalha(audio, proximoTipo)
            end
        end
    end

    local boss = bosses.boss

    if boss then
        if bosses.bossEntrando then
            bosses.timerIntro = bosses.timerIntro - dt
            boss.y = boss.y + (boss.alvoY - boss.y) * 2 * dt

            if bosses.timerIntro <= 0 then
                bosses.timerIntro = 0
                bosses.bossEntrando = false
            end
        else
            if boss.tipo == 5
            and boss.vida <= boss.vidaMaxima / 2 then
                boss.faseFinalAtivada = true
            end
            local faseFinal = boss.faseFinalAtivada

            if boss.tipo == 5 then
                -- O chefe final cruza a arena rumo a bordas aleatórias, sem perseguir o jogador.
                if not boss.alvoX or not boss.alvoY then
                    escolherAlvoBossFinal(boss, larguraTela, alturaTela)
                end

                local chegouAoAlvo = moverBossAte(
                    boss,
                    boss.alvoX,
                    boss.alvoY,
                    faseFinal and boss.velocidade * 1.3 or boss.velocidade,
                    dt
                )
                if chegouAoAlvo then
                    escolherAlvoBossFinal(boss, larguraTela, alturaTela)
                end

                -- Regenera vida após um período sem receber dano; ajuste o atraso e a taxa aqui.
                boss.tempoSemDano = boss.tempoSemDano + dt
                if boss.tempoSemDano >= 1.5 then
                    boss.timerRegeneracao = boss.timerRegeneracao + dt
                    if boss.timerRegeneracao >= 0.4 then
                        boss.vida = math.min(
                            boss.vidaMaxima,
                            boss.vida + 1
                        )
                        boss.timerRegeneracao = boss.timerRegeneracao - 0.4
                    end
                end
            elseif boss.tipo == 3 then
                -- Boss 3: ajuste o tempo entre investidas e a duração/força do dash.
                boss.timerDash = boss.timerDash - dt
                if boss.timerDash <= 0 and boss.tempoDash <= 0 then
                    local anguloDash = math.atan2(
                        player.y - boss.y,
                        player.x - boss.x
                    )
                    boss.dashDx = math.cos(anguloDash)
                    boss.dashDy = math.sin(anguloDash)
                    -- Duração do dash; timerDash controla o intervalo entre dashes.
                    boss.tempoDash = 0.65
                    boss.timerDash = 5
                end

                if boss.tempoDash > 0 then
                    boss.tempoDash = math.max(0, boss.tempoDash - dt)
                    boss.x = boss.x + boss.dashDx * boss.velocidade * 2 * dt
                    boss.y = boss.y + boss.dashDy * boss.velocidade * 2 * dt
                else
                    local angulo = math.atan2(
                        player.y - boss.y,
                        player.x - boss.x
                    )
                    boss.x = boss.x + math.cos(angulo) * boss.velocidade * dt
                    boss.y = boss.y + math.sin(angulo) * boss.velocidade * dt
                end
            elseif boss.tipo == 4 then
                -- Boss 4: a constante controla a altura e a frequência do movimento vertical.
                local diferencaX = player.x - boss.x
                boss.x = boss.x
                    + (diferencaX < 0 and -1 or 1)
                    * math.min(math.abs(diferencaX), boss.velocidade * dt)
                local yAlvo = 115 + math.sin(tempoPartida * 1.4) * 55
                boss.y = boss.y + (yAlvo - boss.y) * math.min(1, dt * 2)
            else
                -- Multiplicador de velocidade do chefe final na segunda metade da vida.
                local velocidade = faseFinal
                    and boss.velocidade * 1.45
                    or boss.velocidade
                local angulo = math.atan2(player.y - boss.y, player.x - boss.x)

                boss.x = boss.x + math.cos(angulo) * velocidade * dt
                boss.y = boss.y + math.sin(angulo) * velocidade * dt
            end

            boss.x = math.max(boss.tamanho / 2, math.min(
                larguraTela - boss.tamanho / 2,
                boss.x
            ))
            boss.y = math.max(boss.tamanho / 2, math.min(
                alturaTela - boss.tamanho / 2,
                boss.y
            ))

            boss.timerTiro = boss.timerTiro - dt

            if boss.timerTiro <= 0 then
                boss.timerTiro = faseFinal
                    and boss.intervaloTiro * 0.9
                    or boss.intervaloTiro
                local angulo = math.atan2(
                    player.y - boss.y,
                    player.x - boss.x
                )
                local quantidade = boss.tipo == 1 and 1
                    or boss.tipo == 2 and 3
                    or boss.tipo == 3 and 3
                    or boss.tipo == 4 and 5
                    or boss.tipo == 5 and 3
                local abertura = boss.tipo == 4 and 0.9
                    or boss.tipo == 5 and 0.75
                    or boss.tipo == 2 and 0.55
                    or 0.32

                -- Duração da janela vulnerável dos bosses 2 e 4.
                if boss.tipo == 2 or boss.tipo == 4 then
                    -- Bosses 2 e 4 só recebem dano durante esta janela após atirar.
                    boss.timerVulneravel = boss.tipo == 2 and 2.5 or 2
                end

                -- Quantidade de projéteis, abertura do leque e velocidade do tiro.
                for indice = 1, quantidade do
                    local deslocamento = quantidade == 1 and 0
                        or (indice - (quantidade + 1) / 2)
                            * abertura / (quantidade - 1)
                    local anguloTiro = angulo + deslocamento
                    local velocidadeTiro = boss.tipo == 5 and 210 or 190

                    table.insert(bosses.tirosInimigos, {
                        x = boss.x,
                        y = boss.y,
                        dx = math.cos(anguloTiro),
                        dy = math.sin(anguloTiro),
                        angulo = anguloTiro,
                        velocidade = velocidadeTiro,
                        tamanho = 30
                    })
                end
            end

            if boss.timerVulneravel > 0 then
                boss.timerVulneravel = math.max(0, boss.timerVulneravel - dt)
            end

            -- Dano de contato entre o chefe e o jogador.
            local encostouNoJogador = colisaoCirculo(
                boss.x,
                boss.y,
                boss.tamanho / 2.3,
                player.x,
                player.y,
                player.tamanho / 2.3
            )

            if encostouNoJogador
            and not escudoAtivo
            and player.tempoInvulneravel <= 0 then
                player.vidas = player.vidas - 1
                player.tempoInvulneravel = 1.2
            end
        end
    end

    -- Move os projéteis do chefe e verifica contato com o jogador.
    for i = #bosses.tirosInimigos, 1, -1 do
        local tiro = bosses.tirosInimigos[i]

        tiro.x = tiro.x + tiro.dx * tiro.velocidade * dt
        tiro.y = tiro.y + tiro.dy * tiro.velocidade * dt

        local acertouJogador = colisaoCirculo(
            tiro.x,
            tiro.y,
            tiro.tamanho / 2.2,
            player.x,
            player.y,
            player.tamanho / 2.2
        )

        local saiuDaTela =
            tiro.x < -50
            or tiro.x > larguraTela + 50
            or tiro.y < -50
            or tiro.y > alturaTela + 50

        if acertouJogador then
            if not escudoAtivo and player.tempoInvulneravel <= 0 then
                player.vidas = player.vidas - 1
                player.tempoInvulneravel = 1
            end

            -- O projétil desaparece ao tocar no jogador.
            table.remove(bosses.tirosInimigos, i)
        elseif saiuDaTela then
            table.remove(bosses.tirosInimigos, i)
        end
    end
end

function Bosses.handlePlayerBullets(bosses, player, audio)
    local pontosGanhos = 0

    for tiroIndex = #player.tiros, 1, -1 do
        local tiro = player.tiros[tiroIndex]
        local boss = bosses.boss

        if boss and not bosses.bossEntrando then
            local acertouBoss = colisaoCirculo(
                tiro.x,
                tiro.y,
                (tiro.tamanho or 32) / 2,
                boss.x,
                boss.y,
                boss.tamanho / 2.2
            )

            if acertouBoss then
                table.remove(player.tiros, tiroIndex)

                local podeReceberDano =
                    (boss.tipo ~= 2 and boss.tipo ~= 4)
                    or boss.timerVulneravel > 0

                if podeReceberDano then
                    boss.vida = boss.vida - (tiro.dano or 1)
                    if boss.tipo == 5 then
                        boss.tempoSemDano = 0
                        boss.timerRegeneracao = 0
                    end

                    if boss.vida <= 0 then
                        pontosGanhos = pontosGanhos + boss.tipo * 300
                        bosses.bossesDerrotados = boss.tipo
                        bosses.ultimoDerrotado = boss.tipo
                        bosses.timerSpawnBoss2 = 25

                        if boss.tipo == 1 then
                            bosses.boss1Derrotado = true
                        elseif boss.tipo == 2 then
                            bosses.boss2Derrotado = true
                        end

                        bosses.boss = nil
                        bosses.bossEntrando = false
                        voltarMusicaDeFundo(audio)
                    end
                end
            end
        end
    end

    return pontosGanhos
end

function Bosses.draw(bosses, assets)
    love.graphics.setColor(1, 1, 1, 1)

    -- Desenha os projéteis inimigos.
    local imagemTiro = assets.images.tiroInimigo
    local escalaTiro = 32 / imagemTiro:getWidth()
    local centroTiroX = imagemTiro:getWidth() / 2
    local centroTiroY = imagemTiro:getHeight() / 2

    for _, tiro in ipairs(bosses.tirosInimigos) do
        love.graphics.draw(
            imagemTiro,
            tiro.x,
            tiro.y,
            tiro.angulo,
            escalaTiro,
            escalaTiro,
            centroTiroX,
            centroTiroY
        )
    end

    -- Desenha o chefe. A barra de vida e o aviso ficam para ui.lua.
    local boss = bosses.boss

    if boss then
        local imagem

        if boss.tipo == 2 then
            imagem = assets.images.boss2
        elseif boss.tipo == 3 then
            imagem = assets.images.boss3
        elseif boss.tipo == 4 then
            imagem = assets.images.boss4
        elseif boss.tipo == 5 then
            imagem = assets.images.finalBoss
        else
            imagem = assets.images.boss
        end

        local escala = boss.tamanho / imagem:getWidth()
        local centroX = imagem:getWidth() / 2
        local centroY = imagem:getHeight() / 2

        love.graphics.draw(
            imagem,
            boss.x,
            boss.y,
            0,
            escala,
            escala,
            centroX,
            centroY
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Bosses