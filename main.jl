using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using ColorTypes

@assert SDL2.init() == 0

w = Int32(800)
h = Int32(600)

try
    @show win = SDL2.CreateWindow("Reaction diffusion", Int32(SDL2.WINDOWPOS_CENTERED()), Int32(SDL2.WINDOWPOS_CENTERED()), w, h, UInt32(0))

    @show render = SDL2.CreateRenderer(win, Int32(-1), UInt32(0))
    SDL2.SetRenderDrawColor(render, 0, 0, 0, 255)
    SDL2.RenderClear(render)
    SDL2.RenderPresent(render)

    texture = SDL2.CreateTexture(render, SDL2.PIXELFORMAT_ARGB8888,
                                 Int32(SDL2.TEXTUREACCESS_STREAMING), w, h)

    # hopefully it can read the array data
    data = fill(ARGB32(1, 0, 0, 1), w * h)

    @show SDL2.UpdateTexture(texture, C_NULL, pointer(data), Int32(w * sizeof(UInt32)))
    SDL2.RenderCopy(render, texture, C_NULL, C_NULL)
    SDL2.RenderPresent(render)

    sleep(1)

finally
    SDL2.Quit()
end
