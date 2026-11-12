shader_type canvas_item;
// Scanlines sutis para o fundo dos menus (linhas claras e finas sobre o fundo escuro).
// Cor, opacidade e altura do retângulo vêm do script do menu (Palette.TEXT e Palette.SCANLINE_ALPHA).

// Cor das linhas (definida pelo script a partir da Palette).
uniform vec4 line_color : source_color = vec4(0.92, 0.87, 0.73, 1.0);
// Opacidade das linhas: nunca acima de 0.08.
uniform float line_alpha : hint_range(0.0, 0.08) = 0.05;
// Altura de cada linha em pixels do viewport virtual (2 = uma linha clara a cada 4 px).
uniform float line_height = 2.0;
// Altura do retângulo em pixels do viewport virtual (definida pelo script ao redimensionar).
uniform float rect_height = 648.0;

void fragment() {
	float row = floor(UV.y * rect_height / line_height);
	float on = mod(row, 2.0);
	COLOR = vec4(line_color.rgb, line_alpha * on);
}
