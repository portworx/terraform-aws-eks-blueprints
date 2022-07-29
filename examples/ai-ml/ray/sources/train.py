import argparse
from typing import Dict

import ray
from ray.air import session
from ray.air import Checkpoint

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets
from torchvision.transforms import ToTensor

import ray.train as train
from ray.train.torch import TorchTrainer
from ray.air.config import ScalingConfig
import s3fs

#ray.shutdown()

# Download training data from open datasets.
training_data = datasets.FashionMNIST(
    root="~/data",
    train=True,
    download=True,
    transform=ToTensor(),
)

# Download test data from open datasets.
test_data = datasets.FashionMNIST(
    root="~/data",
    train=False,
    download=True,
    transform=ToTensor(),
)


# Define model
class NeuralNetwork(nn.Module):
    def __init__(self):
        super(NeuralNetwork, self).__init__()
        self.flatten = nn.Flatten()
        self.linear_relu_stack = nn.Sequential(
            nn.Linear(28 * 28, 512),
            nn.ReLU(),
            nn.Linear(512, 512),
            nn.ReLU(),
            nn.Linear(512, 10),
            nn.ReLU(),
        )

    def forward(self, x):
        x = self.flatten(x)
        logits = self.linear_relu_stack(x)
        return logits


def train_epoch(dataloader, model, loss_fn, optimizer):
    size = len(dataloader.dataset) // session.get_world_size()
    model.train()
    for batch, (X, y) in enumerate(dataloader):
        # Compute prediction error
        pred = model(X)
        loss = loss_fn(pred, y)

        # Backpropagation
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        if batch % 100 == 0:
            loss, current = loss.item(), batch * len(X)
            print(f"loss: {loss:>7f}  [{current:>5d}/{size:>5d}]")


def validate_epoch(dataloader, model, loss_fn):
    size = len(dataloader.dataset) // session.get_world_size()
    num_batches = len(dataloader)
    model.eval()
    test_loss, correct = 0, 0
    with torch.no_grad():
        for X, y in dataloader:
            pred = model(X)
            test_loss += loss_fn(pred, y).item()
            correct += (pred.argmax(1) == y).type(torch.float).sum().item()
    test_loss /= num_batches
    correct /= size
    print(
        f"Test Error: \n "
        f"Accuracy: {(100 * correct):>0.1f}%, "
        f"Avg loss: {test_loss:>8f} \n"
    )
    return test_loss


def train_func(config: Dict):
    batch_size = config["batch_size"]
    lr = config["lr"]
    epochs = config["epochs"]

    worker_batch_size = batch_size // session.get_world_size()

    # Create data loaders.
    train_dataloader = DataLoader(training_data, batch_size=worker_batch_size)
    test_dataloader = DataLoader(test_data, batch_size=worker_batch_size)

    train_dataloader = train.torch.prepare_data_loader(train_dataloader)
    test_dataloader = train.torch.prepare_data_loader(test_dataloader)

    # Create model.
    model = NeuralNetwork()
    model = train.torch.prepare_model(model)

    loss_fn = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(model.parameters(), lr=lr)

    loss_results = []

    for epoch in range(epochs):
        train_epoch(train_dataloader, model, loss_fn, optimizer)
        loss = validate_epoch(test_dataloader, model, loss_fn)
        loss_results.append(loss)

        checkpoint = Checkpoint.from_dict(
            dict(epoch=epoch, model=model.module.state_dict())
        )
        session.report(dict(loss=loss), checkpoint=checkpoint)
        
    return loss_results


def train_fashion_mnist(num_workers=2, use_gpu=False):
    trainer = TorchTrainer(
        train_func,
        train_loop_config={"lr": 1e-3, "batch_size": 64, "epochs": 1},
        scaling_config=ScalingConfig(num_workers=num_workers, use_gpu=use_gpu),
    )

    result = trainer.fit()
        
    model_path = result.checkpoint._local_path    

    return model_path


parser = argparse.ArgumentParser()
parser.add_argument(
    "--address", required=False, type=str, help="the address to use for Ray"
)
parser.add_argument(
    "--num-workers",
    "-n",
    type=int,
    default=2,
    help="Sets number of workers for training.",
)
parser.add_argument(
    "--use-gpu", action="store_true", default=False, help="Enables GPU training"
)

args, _ = parser.parse_known_args()

ray.init(address=args.address, runtime_env={"pip": [
                                            "torch", 
                                            "scikit-learn",
                                            "transformers",
                                            "pandas",
                                            "datasets",
                                            "accelerate",
                                            "scikit-learn",
                                            "mlflow", 
                                            "tensorboard"                         
                                         ]
                                 })

model_path = train_fashion_mnist(num_workers=args.num_workers, use_gpu=args.use_gpu)

print('model_path: {}'.format(model_path))

s3_file = s3fs.S3FileSystem()
s3_path = "ray-demo-models-20220729044638883100000001/model"
s3_file.put(model_path, s3_path, recursive=True)
