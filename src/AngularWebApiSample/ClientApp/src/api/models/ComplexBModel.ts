﻿// This file has been AUTOGENERATED by TypeWriter (https://frhagn.github.io/Typewriter/).
// Do not modify it.


import { IComplexBaseModel, ComplexBaseModel } from './ComplexBaseModel';

export interface IComplexBModel extends IComplexBaseModel {
    isActive?: boolean;
}

export class ComplexBModel extends ComplexBaseModel implements IComplexBModel {
    public isActive: boolean;

    constructor(initObj?: IComplexBModel) {
        super(initObj);
        this.$type = 'AngularWebApiSample.Models.ComplexBModel,'
            + 'AngularWebApiSample.Models';
        if (initObj) {
            this.isActive = initObj.isActive || false;
        } else {
            this.isActive = false;
        }
    }
}


