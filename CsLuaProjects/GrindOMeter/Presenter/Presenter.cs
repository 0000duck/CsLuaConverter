﻿namespace GrindOMeter.Presenter
{
    using System.Collections.Generic;
    using System.Linq;
    using Model;
    using Model.Entity;
    using View;

    public class Presenter
    {
        private static Dictionary<EntityType, string> entityTypes = new Dictionary<EntityType, string>()
        {
            { EntityType.Currency, "Currencies"},
            { EntityType.Item, "Items"},
        };

        private readonly Dictionary<IEntityId, IEntitySample> initialTrackingSample;
        private readonly IModel model;
        private readonly IView view;

        public Presenter(IModel model, IView view)
        {
            this.initialTrackingSample = new Dictionary<IEntityId, IEntitySample>();
            this.model = model;
            this.view = view;

            this.view.SetUpdateAction(this.UpdateVelocity);
            this.view.SetTrackingEntityHandlers(this.ResetSample, this.RemoveTracking);
            this.view.SetTrackButtonOnClick(this.TrackOnClick);

            this.LoadEntities();
        }

        private void LoadEntities()
        {
            this.model.LoadTrackedEntities().ForEach(AddEntity);
        }

        private void AddEntity(IEntity entity)
        {
            var id = GetId(entity);
            this.initialTrackingSample[id] = this.model.GetCurrentSample(id.Type, id.Id);
            this.view.AddTrackingEntity(id, entity.Name, entity.IconPath);
            
        }

        private static IEntityId GetId(IEntity entity)
        {
            return new EntityId(entity.Type, entity.Id);
        }

        private void UpdateVelocity()
        {
            foreach (var entityId in this.initialTrackingSample.Keys)
            {
                var intialSample = this.initialTrackingSample[entityId];
                var currentSample = this.model.GetCurrentSample(entityId.Type, entityId.Id);
                this.view.UpdateTrackingEntityVelocity(entityId, currentSample.Amount, GetVelocity(intialSample, currentSample));
            }
        }

        private static double GetVelocity(IEntitySample initialSample, IEntitySample currentSample)
        {
            var deltaA = currentSample.Amount - initialSample.Amount;
            var deltaT = (currentSample.Timestamp - initialSample.Timestamp) / (60*60);
            if (deltaT > 0)
            {
                return deltaA / deltaT;
            }

            return 0;
        }

        private void ResetSample(IEntityId id)
        {
            this.initialTrackingSample[id] = this.model.GetCurrentSample(id.Type, id.Id);
            this.view.UpdateTrackingEntityVelocity(id, this.initialTrackingSample[id].Amount, 0);
        }

        private void RemoveTracking(IEntityId id)
        {
            this.model.SaveEntityTrackingFlag(id.Type, id.Id, false);
            this.view.RemoveTrackingEntity(id);
        }

        private void TrackOnClick()
        {
            var selection = new EntitySelection();

            foreach (var entityType in entityTypes.Keys)
            {
                selection[entityTypes[entityType]] = this.model.GetAvailableEntities(entityType)
                    .Select(entity => (ITrackableEntity) new TrackableEntity(entity, this.TrackEntity)).ToList();
            }

            this.view.ShowEntitySelection(selection);
        }

        private void TrackEntity(IEntity entity)
        {
            this.model.SaveEntityTrackingFlag(entity.Type, entity.Id, true);
            
            var id = GetId(entity);
            this.view.AddTrackingEntity(id, entity.Name, entity.IconPath);
            this.ResetSample(id);
        }
    }
}