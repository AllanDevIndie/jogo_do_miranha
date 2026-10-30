local Assets = {
    images = {},
    audio = {}
}

function Assets.load()
    local imagePaths = {
        jogador = "image/superhero.png",
        tiroJogador = "image/power.png",
        inimigo = "image/enemy.png",
        inimigo2 = "image/enemy2.png",
        boss = "image/boss.png",
        boss2 = "image/cthulhu.png",
        tiroInimigo = "image/enemyPower.png",
        fundo = "image/cenary.jpg",
        cena2 = "image/cena2.jpg",
        coracao = "image/heart.png",
        powerupTiroRapido = "image/powerup.png",
        powerupEscudo = "image/powerup_shield.png"
    }

    for nome, caminho in pairs(imagePaths) do
        Assets.images[nome] = love.graphics.newImage(caminho)
    end

    Assets.audio.musicaFundo =
        love.audio.newSource("songs/theme-spiderman-8-bit.mp3", "stream")
    Assets.audio.musicaFundo:setLooping(true)
    Assets.audio.musicaFundo:setVolume(0.5)

    Assets.audio.musicaBatalha =
        love.audio.newSource("songs/battle.mp3", "stream")
    Assets.audio.musicaBatalha:setLooping(true)
    Assets.audio.musicaBatalha:setVolume(0.5)

    Assets.audio.musicaBoss2 =
        love.audio.newSource("songs/Orbital Colossus.mp3", "stream")
    Assets.audio.musicaBoss2:setLooping(true)
    Assets.audio.musicaBoss2:setVolume(0.5)
end

return Assets