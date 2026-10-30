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

local function criarBoss(bosses, tipo, larguraTela)
    bosses.bossEntrando = true
    bosses.timerIntro = 5

    if tipo == 1 then
        bosses.boss = {
            tipo = 1,
            nome = "Chefão",
            x = larguraTela / 2,
            y = -120,
            alvoY = 120,
            velocidade = 170,
            tamanho = 96,
            vida = 30,
            vidaMaxima = 30,
            timerTiro = 1,
            intervaloTiro = 1.3
        }
    else
        bosses.boss = {
            tipo = 2,
            nome = "CTHULHU",
            x = larguraTela / 2,
            y = -130,
            alvoY = 120,
            velocidade = 145,
            tamanho = 110,
            vida = 60,
            vidaMaxima = 60,
            timerTiro = 1,
            intervaloTiro = 5,
            timerVulneravel = 0
        }
    end
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
    bosses.boss = nil
    bosses.bossEntrando = false
    bosses.tirosInimigos = {}
    bosses.timerSpawnBoss2 = -1

    if tipo == 1 then
        bosses.boss1JaApareceu = true
        bosses.boss1Derrotado = false
        bosses.boss2JaApareceu = false
        bosses.boss2Derrotado = false
    elseif tipo == 2 then
        bosses.boss1JaApareceu = true
        bosses.boss1Derrotado = true
        bosses.boss2JaApareceu = true
        bosses.boss2Derrotado = false
    else
        return
    end

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
    escudoAtivo
)
    -- Primeiro chefe: aparece aos 30 segundos.
    if tempoPartida >= 30 and not bosses.boss1JaApareceu then
        bosses.boss1JaApareceu = true
        criarBoss(bosses, 1, larguraTela)
        tocarMusicaDeBatalha(audio, 1)
    end

    -- Segundo chefe: aparece 30 segundos depois que o primeiro é derrotado.
    if bosses.boss1Derrotado
    and not bosses.boss2JaApareceu
    and not bosses.boss then
        bosses.timerSpawnBoss2 = bosses.timerSpawnBoss2 - dt

        if bosses.timerSpawnBoss2 <= 0 then
            bosses.boss2JaApareceu = true
            criarBoss(bosses, 2, larguraTela)
            tocarMusicaDeBatalha(audio, 2)
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
            -- O chefe persegue o jogador.
            local angulo = math.atan2(player.y - boss.y, player.x - boss.x)

            boss.x = boss.x + math.cos(angulo) * boss.velocidade * dt
            boss.y = boss.y + math.sin(angulo) * boss.velocidade * dt

            boss.timerTiro = boss.timerTiro - dt

            if boss.timerTiro <= 0 then
                boss.timerTiro = boss.intervaloTiro

                if boss.tipo == 1 then
                    -- O primeiro chefe atira na direção atual do jogador.
                    local anguloTiro = math.atan2(
                        player.y - boss.y,
                        player.x - boss.x
                    )

                    table.insert(bosses.tirosInimigos, {
                        x = boss.x,
                        y = boss.y,
                        dx = math.cos(anguloTiro),
                        dy = math.sin(anguloTiro),
                        angulo = anguloTiro,
                        velocidade = 230,
                        tamanho = 32
                    })
                else
                    -- O Cthulhu dispara em três direções e fica vulnerável.
                    boss.timerVulneravel = 3

                    local projeteis = {
                        {dx = 0, dy = -1, angulo = -math.pi / 2},
                        {dx = -0.7071, dy = 0.7071, angulo = math.pi * 0.75},
                        {dx = 0.7071, dy = 0.7071, angulo = math.pi * 0.25}
                    }

                    for _, projetil in ipairs(projeteis) do
                        table.insert(bosses.tirosInimigos, {
                            x = boss.x,
                            y = boss.y,
                            dx = projetil.dx,
                            dy = projetil.dy,
                            angulo = projetil.angulo,
                            velocidade = 240,
                            tamanho = 32
                        })
                    end
                end
            end

            if boss.tipo == 2 and boss.timerVulneravel > 0 then
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
                    boss.tipo == 1
                    or boss.timerVulneravel > 0

                if podeReceberDano then
                    boss.vida = boss.vida - 1

                    if boss.vida <= 0 then
                        if boss.tipo == 1 then
                            pontosGanhos = pontosGanhos + 300
                            bosses.boss1Derrotado = true
                            bosses.timerSpawnBoss2 = 30
                        else
                            pontosGanhos = pontosGanhos + 600
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