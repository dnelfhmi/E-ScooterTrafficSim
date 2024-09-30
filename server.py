from mesa.visualization.ModularVisualization import ModularServer
from mesa.visualization.modules import CanvasGrid
from main import MyGeoModel

def agent_portrayal(agent):
    return {
        "Shape": "circle",
        "Color": "blue",
        "Filled": "true",
        "Radius": 0.5,
    }

grid = CanvasGrid(agent_portrayal, 10, 10, 500, 500)

model_params = {
    "shp_file": "path/to/your/shapefile.shp",
}

server = ModularServer(
    MyGeoModel,
    [grid],
    "E-Scooter Traffic Simulation",
    model_params
)

if __name__ == "__main__":
    server.port = 8521
    server.launch()
