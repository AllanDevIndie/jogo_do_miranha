local SecretBoss={}

local function colisaoCirculo(x1,y1,r1,x2,y2,r2)
    local dx=x1-x2
    local dy=y1-y2
    return dx*dx+dy*dy<(r1+r2)*(r1+r2)
end

local function tocarMusicaDuelo(audio)
    if not audio then return end
    if audio.musicaMenu then audio.musicaMenu:stop() end
    if audio.musicaFundo then audio.musicaFundo:stop() end
    if audio.musicaBatalha then audio.musicaBatalha:stop() end
    if audio.musicaBoss2 then audio.musicaBoss2:stop() end
    if audio.musicaBatalha then audio.musicaBatalha:play() end
end

local function voltarMusicaFundo(audio)
    if not audio then return end
    if audio.musicaBatalha then audio.musicaBatalha:stop() end
    if audio.musicaBoss2 then audio.musicaBoss2:stop() end
    if audio.musicaFundo then audio.musicaFundo:play() end
end

function SecretBoss.new()
    return {boss=nil,bossEntrando=false,timerIntro=0,tirosInimigos={}}
end

function SecretBoss.reset(state)
    state.boss=nil
    state.bossEntrando=false
    state.timerIntro=0
    state.tirosInimigos={}
end

function SecretBoss.start(state,player,w,h,audio)
    state.boss={
        tipo=3,nome="CHEFE SECRETO",x=w/2,y=-100,
        alvoY=math.max(100,h*0.22),velocidade=player.velocidade,
        tamanho=88,vida=3,vidaMaxima=3,timerTiro=0.8,
        intervaloTiro=0.4,timerTiroRapido=0,timerEscudo=0
    }
    state.bossEntrando=true
    state.timerIntro=3
    state.tirosInimigos={}
    tocarMusicaDuelo(audio)
end

function SecretBoss.isActive(state)
    return state and state.boss~=nil
end

function SecretBoss.collectItem(state,tipo)
    local boss=state.boss
    if not boss then return end
    if tipo=="vida" then
        boss.vida=math.min(boss.vidaMaxima,boss.vida+1)
    elseif tipo=="tiro_rapido" then
        boss.timerTiroRapido=10
    elseif tipo=="escudo" then
        boss.timerEscudo=10
    end
end

function SecretBoss.update(state,dt,player,w,h,escudoPlayerAtivo,item)
    local boss=state.boss
    if not boss then return end
    boss.timerTiroRapido=math.max(0,boss.timerTiroRapido-dt)
    boss.timerEscudo=math.max(0,boss.timerEscudo-dt)

    if state.bossEntrando then
        state.timerIntro=math.max(0,state.timerIntro-dt)
        boss.y=boss.y+(boss.alvoY-boss.y)*math.min(1,2.5*dt)
        if state.timerIntro<=0 then state.bossEntrando=false end
    else
        local dx=boss.x-player.x
        local dy=boss.y-player.y
        local distancia=math.sqrt(dx*dx+dy*dy)
        if distancia<0.001 then dx,dy,distancia=1,0,1 end
        local buscarItem=false
        if item then
            local ix=item.x-boss.x
            local iy=item.y-boss.y
            buscarItem=ix*ix+iy*iy<420*420
            if buscarItem then dx,dy=ix,iy;distancia=math.sqrt(dx*dx+dy*dy) end
        end
        if distancia>0.001 then dx,dy=dx/distancia,dy/distancia end
        -- Sem item próximo, dx/dy apontam para longe do jogador.
        -- Com um item próximo, o chefe tenta alcançá-lo.
        boss.velocidade=player.velocidade
        boss.x=boss.x+dx*boss.velocidade*dt
        boss.y=boss.y+dy*boss.velocidade*dt
        local margem=boss.tamanho/2
        boss.x=math.max(margem,math.min(w-margem,boss.x))
        boss.y=math.max(margem,math.min(h-margem,boss.y))

        boss.timerTiro=boss.timerTiro-dt
        if boss.timerTiro<=0 then
            local rapido=boss.timerTiroRapido>0
            local intervalo=boss.vida==1 and 0.3 or boss.intervaloTiro
            boss.timerTiro=rapido and intervalo/2 or intervalo
            local angulo=math.atan2(player.y-boss.y,player.x-boss.x)
            local velocidade=rapido and 750 or 500
            table.insert(state.tirosInimigos,{
                x=boss.x,y=boss.y,dx=math.cos(angulo),dy=math.sin(angulo),
                angulo=angulo,velocidade=velocidade,tamanho=32
            })
        end
    end

    for i=#state.tirosInimigos,1,-1 do
        local tiro=state.tirosInimigos[i]
        tiro.x=tiro.x+tiro.dx*tiro.velocidade*dt
        tiro.y=tiro.y+tiro.dy*tiro.velocidade*dt
        local acertou=colisaoCirculo(tiro.x,tiro.y,tiro.tamanho/2.2,
            player.x,player.y,player.tamanho/2.2)
        local fora=tiro.x < -50 or tiro.x > w+50
            or tiro.y < -50 or tiro.y > h+50
        if acertou then
            if not escudoPlayerAtivo and player.tempoInvulneravel<=0 then
                player.vidas=player.vidas-1
                player.tempoInvulneravel=1
            end
            table.remove(state.tirosInimigos,i)
        elseif fora then
            table.remove(state.tirosInimigos,i)
        end
    end
end

function SecretBoss.handlePlayerBullets(state,player,audio)
    local boss=state.boss
    if not boss or state.bossEntrando then return false end
    for i=#player.tiros,1,-1 do
        local tiro=player.tiros[i]
        if colisaoCirculo(tiro.x,tiro.y,(tiro.tamanho or 32)/2,
            boss.x,boss.y,boss.tamanho/2.2) then
            table.remove(player.tiros,i)
            if boss.timerEscudo<=0 then
                boss.vida=boss.vida-1
                if boss.vida<=0 then
                    state.boss=nil
                    state.bossEntrando=false
                    state.tirosInimigos={}
                    voltarMusicaFundo(audio)
                    return true
                end
            end
        end
    end
    return false
end

function SecretBoss.draw(state,assets)
    local tiro=assets.images.tiroJogador
    local escala=32/tiro:getWidth()
    for _,bala in ipairs(state.tirosInimigos) do
        love.graphics.setColor(1,0.35,0.35,1)
        love.graphics.draw(tiro,bala.x,bala.y,bala.angulo,escala,escala,
            tiro:getWidth()/2,tiro:getHeight()/2)
    end
    local boss=state.boss
    if boss then
        local imagem=assets.images.bossSecreto
        local s=boss.tamanho/imagem:getWidth()
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(imagem,boss.x,boss.y,0,s,s,
            imagem:getWidth()/2,imagem:getHeight()/2)
        if boss.timerEscudo>0 then
            love.graphics.setColor(0.2,0.8,1,0.5)
            love.graphics.circle("line",boss.x,boss.y,boss.tamanho*0.7)
        end
    end
    love.graphics.setColor(1,1,1,1)
end

return SecretBoss